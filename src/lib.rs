//! SurrealDB schema migration runner.
//!
//! Migration files live in `migrations/up/` and `migrations/down/` as
//! paired `<name>.surql` files (same stem in both folders), embedded
//! into the binary at compile time via [`rust-embed`]. Files are sorted
//! lexicographically; use a zero-padded numeric prefix (`0001_`,
//! `0002_`, …) to control order.
//!
//! [`rust-embed`]: https://github.com/pyros2097/rust-embed
//!
//! # Why statement-by-statement?
//!
//! An earlier version of this runner wrapped each migration in
//! `BEGIN TRANSACTION; … COMMIT;` and submitted the whole thing as a
//! single query. SurrealDB 3.x's schema DDL doesn't always honour
//! transactional rollback — we observed migrations that half-applied
//! (e.g. `DEFINE TABLE IF NOT EXISTS book SCHEMAFULL` silently no-op'd
//! against a drifted SCHEMALESS table) yet still wrote the `_migrations`
//! marker. That made `migrate up` falsely report success.
//!
//! The current runner:
//!   1. Splits each file into top-level statements (respecting `'…'`,
//!      `"…"` strings, `--` line comments, and `{…}` blocks for EVENT
//!      bodies).
//!   2. Runs each statement individually and fails loud on the first
//!      error.
//!   3. After every statement in a file applies, runs `INFO FOR DB`
//!      and verifies that every `DEFINE TABLE <name>` named in the
//!      file actually exists.
//!   4. Only then writes the `_migrations` marker. A partial apply
//!      leaves the marker absent, so the next `migrate up` re-applies
//!      (safely, because every `DEFINE` uses `OVERWRITE`).
//!
//! ```ignore
//! use merk_migrations::Migrator;
//! Migrator::up(&db, None).await?;       // apply everything pending
//! Migrator::down(&db, Some(1)).await?;  // roll back the last migration
//! ```

use rust_embed::RustEmbed;
use serde::{Deserialize, Serialize};
use surrealdb::Surreal;
use surrealdb::engine::any::Any;
use surrealdb::types::{RecordId, SurrealValue};
use tracing::{info, warn};

#[derive(RustEmbed)]
#[folder = "migrations/"]
struct Files;

#[derive(Debug, Serialize, Deserialize, SurrealValue)]
#[surreal(crate = "surrealdb::types")]
struct MigrationRecord {
    pub id: RecordId,
    pub name: String,
    pub batch: Option<u32>,
}

#[derive(Debug, thiserror::Error)]
pub enum MigrationError {
    #[error("SurrealDB error: {0}")]
    Database(#[from] surrealdb::Error),
    #[error("Migration file encoding error: {0}")]
    Encoding(#[from] std::str::Utf8Error),
    #[error("No down migration file for '{0}'")]
    NoDownFile(String),
    #[error("Failed to apply migration '{name}' at statement #{stmt}: {cause}\n  SQL: {sql}")]
    Apply {
        name: String,
        stmt: usize,
        sql: String,
        cause: String,
    },
    #[error("Failed to rollback migration '{name}' at statement #{stmt}: {cause}\n  SQL: {sql}")]
    Rollback {
        name: String,
        stmt: usize,
        sql: String,
        cause: String,
    },
    #[error(
        "Migration '{name}' applied but verification failed: expected tables {expected:?}, missing {missing:?}"
    )]
    Verification {
        name: String,
        expected: Vec<String>,
        missing: Vec<String>,
    },
}

#[derive(Debug)]
pub struct MigrationStatus {
    pub name: String,
    pub applied: bool,
    pub batch: Option<u32>,
}

pub struct Migrator;

impl Migrator {
    /// Apply all pending migrations, or only the next `steps` if given.
    pub async fn up(db: &Surreal<Any>, steps: Option<u32>) -> Result<(), MigrationError> {
        ensure_migrations_table(db).await?;

        let applied_set: std::collections::HashSet<String> =
            get_applied(db).await?.into_iter().map(|r| r.name).collect();

        let pending: Vec<String> = discover_migrations()
            .into_iter()
            .filter(|n| !applied_set.contains(n))
            .collect();

        if pending.is_empty() {
            info!("No pending migrations.");
            return Ok(());
        }

        let batch = next_batch(db).await?;
        let to_apply: Vec<String> = match steps {
            Some(n) => pending.into_iter().take(n as usize).collect(),
            None => pending,
        };

        for name in &to_apply {
            apply_one(db, name, batch).await?;
        }

        info!("Migrations applied successfully.");
        Ok(())
    }

    /// Roll back the last `steps` applied migrations (default: 1).
    pub async fn down(db: &Surreal<Any>, steps: Option<u32>) -> Result<(), MigrationError> {
        ensure_migrations_table(db).await?;

        let to_rollback: Vec<MigrationRecord> = get_applied(db)
            .await?
            .into_iter()
            .rev()
            .take(steps.unwrap_or(1) as usize)
            .collect();

        if to_rollback.is_empty() {
            info!("No applied migrations to roll back.");
            return Ok(());
        }

        for record in &to_rollback {
            rollback_one(db, &record.name).await?;
        }

        Ok(())
    }

    /// Drop all tables via `INFO FOR DB`, then re-apply every migration.
    /// Doesn't need `down/` files — it nukes everything directly.
    pub async fn fresh(db: &Surreal<Any>) -> Result<(), MigrationError> {
        let mut response = db
            .query("LET $i = INFO FOR DB; RETURN object::keys($i.tables)")
            .await?
            .check()?;
        let table_names: Vec<String> = response.take(1).unwrap_or_default();

        for table_name in &table_names {
            if table_name != "_migrations" {
                db.query(format!("REMOVE TABLE IF EXISTS `{}`", table_name))
                    .await?
                    .check()?;
                info!("Dropped table: {}", table_name);
            }
        }

        db.query("DELETE FROM _migrations").await?.check()?;
        info!("Database cleared, re-applying all migrations...");
        Self::up(db, None).await
    }

    /// Roll back every applied migration via its `down/` file, then
    /// re-apply everything. Exercises the down path (CI should run this).
    pub async fn refresh(db: &Surreal<Any>) -> Result<(), MigrationError> {
        ensure_migrations_table(db).await?;
        let count = get_applied(db).await?.len() as u32;
        if count > 0 {
            Self::down(db, Some(count)).await?;
        }
        info!("Re-applying all migrations...");
        Self::up(db, None).await
    }

    /// List every known migration with its applied state and batch.
    pub async fn status(db: &Surreal<Any>) -> Result<Vec<MigrationStatus>, MigrationError> {
        ensure_migrations_table(db).await?;

        let applied_map: std::collections::HashMap<String, MigrationRecord> = get_applied(db)
            .await?
            .into_iter()
            .map(|r| (r.name.clone(), r))
            .collect();

        Ok(discover_migrations()
            .into_iter()
            .map(|name| match applied_map.get(&name) {
                Some(r) => MigrationStatus {
                    name,
                    applied: true,
                    batch: r.batch,
                },
                None => MigrationStatus {
                    name,
                    applied: false,
                    batch: None,
                },
            })
            .collect())
    }
}

// ── per-migration workhorses ─────────────────────────────────────────────────

async fn apply_one(db: &Surreal<Any>, name: &str, batch: u32) -> Result<(), MigrationError> {
    info!("Applying migration: {}", name);
    let sql = load_file(&format!("up/{}.surql", name))?;
    let statements = split_statements(&sql);

    for (idx, stmt) in statements.iter().enumerate() {
        db.query(stmt.as_str())
            .await
            .map_err(|e| MigrationError::Apply {
                name: name.to_string(),
                stmt: idx + 1,
                sql: truncate(stmt, 200),
                cause: e.to_string(),
            })?
            .check()
            .map_err(|e| MigrationError::Apply {
                name: name.to_string(),
                stmt: idx + 1,
                sql: truncate(stmt, 200),
                cause: e.to_string(),
            })?;
    }

    verify_applied(db, name, &sql).await?;

    // Marker insert is the very last step. If anything above failed we
    // skipped this, leaving the migration unmarked so the next `up`
    // re-applies it (idempotent thanks to OVERWRITE).
    db.query(
        "CREATE _migrations SET name = $name, batch = $batch, applied_at = time::now()",
    )
    .bind(("name", name.to_string()))
    .bind(("batch", batch))
    .await?
    .check()?;

    info!("Applied: {}", name);
    Ok(())
}

async fn rollback_one(db: &Surreal<Any>, name: &str) -> Result<(), MigrationError> {
    info!("Rolling back: {}", name);
    let sql = load_file(&format!("down/{}.surql", name))
        .map_err(|_| MigrationError::NoDownFile(name.to_string()))?;
    let statements = split_statements(&sql);

    for (idx, stmt) in statements.iter().enumerate() {
        db.query(stmt.as_str())
            .await
            .map_err(|e| MigrationError::Rollback {
                name: name.to_string(),
                stmt: idx + 1,
                sql: truncate(stmt, 200),
                cause: e.to_string(),
            })?
            .check()
            .map_err(|e| MigrationError::Rollback {
                name: name.to_string(),
                stmt: idx + 1,
                sql: truncate(stmt, 200),
                cause: e.to_string(),
            })?;
    }

    db.query("DELETE FROM _migrations WHERE name = $name")
        .bind(("name", name.to_string()))
        .await?
        .check()?;

    info!("Rolled back: {}", name);
    Ok(())
}

/// Read `DEFINE TABLE <[OVERWRITE]> <name>` mentions out of the SQL,
/// then confirm each one shows up in `INFO FOR DB`. Cheap insurance
/// against silent partial applies.
async fn verify_applied(db: &Surreal<Any>, name: &str, sql: &str) -> Result<(), MigrationError> {
    let expected = extract_defined_tables(sql);
    if expected.is_empty() {
        return Ok(());
    }

    let mut response = db
        .query("LET $i = INFO FOR DB; RETURN object::keys($i.tables)")
        .await?
        .check()?;
    let existing: Vec<String> = response.take(1).unwrap_or_default();
    let existing: std::collections::HashSet<String> = existing.into_iter().collect();

    let missing: Vec<String> = expected
        .iter()
        .filter(|t| !existing.contains(*t))
        .cloned()
        .collect();

    if !missing.is_empty() {
        return Err(MigrationError::Verification {
            name: name.to_string(),
            expected,
            missing,
        });
    }

    Ok(())
}

// ── SurrealQL parsing helpers ────────────────────────────────────────────────

/// Split a `.surql` file into top-level statements. Respects:
///   - `--` line comments
///   - `/* … */` block comments
///   - single and double-quoted strings (with `\` escapes)
///   - `{ … }` blocks (for EVENT bodies that contain `;` internally)
///
/// Returns statements with surrounding whitespace trimmed and trailing
/// `;` removed. Empty statements are skipped.
fn split_statements(sql: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut buf = String::new();
    let mut chars = sql.chars().peekable();
    let mut brace_depth: i32 = 0;
    let mut string_quote: Option<char> = None;

    while let Some(c) = chars.next() {
        // Inside a string literal: copy verbatim, watching for end quote.
        if let Some(q) = string_quote {
            buf.push(c);
            if c == '\\' {
                if let Some(&next) = chars.peek() {
                    buf.push(next);
                    chars.next();
                }
            } else if c == q {
                string_quote = None;
            }
            continue;
        }

        // Line comment.
        if c == '-' && chars.peek() == Some(&'-') {
            // Discard until newline.
            while let Some(&next) = chars.peek() {
                if next == '\n' {
                    break;
                }
                chars.next();
            }
            continue;
        }

        // Block comment.
        if c == '/' && chars.peek() == Some(&'*') {
            chars.next(); // consume '*'
            while let Some(c2) = chars.next() {
                if c2 == '*' && chars.peek() == Some(&'/') {
                    chars.next();
                    break;
                }
            }
            continue;
        }

        match c {
            '"' | '\'' => {
                string_quote = Some(c);
                buf.push(c);
            }
            '{' => {
                brace_depth += 1;
                buf.push(c);
            }
            '}' => {
                brace_depth -= 1;
                buf.push(c);
            }
            ';' if brace_depth == 0 => {
                let trimmed = buf.trim().to_string();
                if !trimmed.is_empty() {
                    out.push(trimmed);
                }
                buf.clear();
            }
            _ => buf.push(c),
        }
    }

    // Catch any trailing statement that wasn't terminated by `;`.
    let trimmed = buf.trim().to_string();
    if !trimmed.is_empty() {
        warn!("Statement without trailing semicolon: {}", truncate(&trimmed, 80));
        out.push(trimmed);
    }

    out
}

/// Pull out the table names this migration claims to define. Used by
/// `verify_applied` to confirm they actually showed up.
///
/// Recognises both `DEFINE TABLE <name>` and `DEFINE TABLE OVERWRITE
/// <name>` / `DEFINE TABLE IF NOT EXISTS <name>`. Anything after the
/// table name (SCHEMAFULL, TYPE RELATION, …) is ignored.
fn extract_defined_tables(sql: &str) -> Vec<String> {
    let mut out = Vec::new();
    // Walk through the file in normalized (comments-stripped, single-spaced)
    // form so we can do plain text matching.
    let normalized = strip_comments_and_normalize_ws(sql);
    let tokens: Vec<&str> = normalized.split_whitespace().collect();

    let mut i = 0;
    while i + 2 < tokens.len() {
        if tokens[i].eq_ignore_ascii_case("DEFINE") && tokens[i + 1].eq_ignore_ascii_case("TABLE") {
            let mut j = i + 2;
            // Skip OVERWRITE / IF NOT EXISTS qualifiers.
            while j < tokens.len() {
                let t = tokens[j].to_ascii_uppercase();
                match t.as_str() {
                    "OVERWRITE" | "IF" | "NOT" | "EXISTS" => j += 1,
                    _ => break,
                }
            }
            if j < tokens.len() {
                let name = tokens[j].trim_matches(|c: char| !c.is_ascii_alphanumeric() && c != '_');
                if !name.is_empty() {
                    out.push(name.to_string());
                }
            }
            i = j;
            continue;
        }
        i += 1;
    }
    out
}

fn strip_comments_and_normalize_ws(sql: &str) -> String {
    let mut out = String::with_capacity(sql.len());
    let mut chars = sql.chars().peekable();
    let mut string_quote: Option<char> = None;

    while let Some(c) = chars.next() {
        if let Some(q) = string_quote {
            out.push(c);
            if c == '\\' {
                if let Some(&n) = chars.peek() {
                    out.push(n);
                    chars.next();
                }
            } else if c == q {
                string_quote = None;
            }
            continue;
        }
        if c == '-' && chars.peek() == Some(&'-') {
            while let Some(&n) = chars.peek() {
                if n == '\n' {
                    break;
                }
                chars.next();
            }
            out.push(' ');
            continue;
        }
        if c == '/' && chars.peek() == Some(&'*') {
            chars.next();
            while let Some(c2) = chars.next() {
                if c2 == '*' && chars.peek() == Some(&'/') {
                    chars.next();
                    break;
                }
            }
            out.push(' ');
            continue;
        }
        if c == '"' || c == '\'' {
            string_quote = Some(c);
            out.push(c);
            continue;
        }
        out.push(c);
    }
    out
}

fn truncate(s: &str, max: usize) -> String {
    if s.len() <= max {
        s.to_string()
    } else {
        format!("{}…", &s[..max])
    }
}

// ── _migrations table helpers ────────────────────────────────────────────────

fn discover_migrations() -> Vec<String> {
    let mut names: std::collections::BTreeSet<String> = Default::default();
    for entry in Files::iter() {
        let path = entry.as_ref();
        if let Some(rest) = path
            .strip_prefix("up/")
            .or_else(|| path.strip_prefix("down/"))
        {
            if let Some(base) = rest.strip_suffix(".surql") {
                names.insert(base.to_string());
            }
        }
    }
    names.into_iter().collect()
}

fn load_file(path: &str) -> Result<String, MigrationError> {
    let file = Files::get(path).ok_or_else(|| MigrationError::NoDownFile(path.to_string()))?;
    Ok(std::str::from_utf8(file.data.as_ref())?.to_string())
}

async fn ensure_migrations_table(db: &Surreal<Any>) -> Result<(), MigrationError> {
    db.query("DEFINE TABLE IF NOT EXISTS _migrations SCHEMALESS")
        .await?
        .check()?;
    Ok(())
}

async fn get_applied(db: &Surreal<Any>) -> Result<Vec<MigrationRecord>, MigrationError> {
    let mut response = db
        .query("SELECT * FROM _migrations ORDER BY name ASC")
        .await?
        .check()?;
    Ok(response.take(0)?)
}

async fn next_batch(db: &Surreal<Any>) -> Result<u32, MigrationError> {
    let applied = get_applied(db).await?;
    Ok(applied.iter().filter_map(|r| r.batch).max().unwrap_or(0) + 1)
}

// ── tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_simple_statements() {
        let sql = "DEFINE TABLE a; DEFINE TABLE b;";
        let stmts = split_statements(sql);
        assert_eq!(stmts.len(), 2);
        assert_eq!(stmts[0], "DEFINE TABLE a");
        assert_eq!(stmts[1], "DEFINE TABLE b");
    }

    #[test]
    fn skips_line_comments() {
        let sql = "-- top\nDEFINE TABLE a; -- trailing\nDEFINE TABLE b;";
        let stmts = split_statements(sql);
        assert_eq!(stmts.len(), 2);
    }

    #[test]
    fn respects_braces_in_event_body() {
        let sql = r#"
            DEFINE EVENT e ON TABLE t
                WHEN $event = "CREATE"
            THEN {
                LET $x = 1;
                UPDATE t SET y = $x;
            };
            DEFINE TABLE u;
        "#;
        let stmts = split_statements(sql);
        assert_eq!(stmts.len(), 2);
        assert!(stmts[0].contains("DEFINE EVENT"));
        assert!(stmts[0].contains("LET $x = 1"));
        assert!(stmts[1] == "DEFINE TABLE u");
    }

    #[test]
    fn respects_semicolons_in_strings() {
        let sql = r#"DEFINE FIELD x ON t TYPE string DEFAULT 'a;b;c'; DEFINE TABLE u;"#;
        let stmts = split_statements(sql);
        assert_eq!(stmts.len(), 2);
        assert!(stmts[0].contains("'a;b;c'"));
    }

    #[test]
    fn extracts_table_names_overwrite_and_qualifiers() {
        let sql = r#"
            DEFINE TABLE OVERWRITE user SCHEMAFULL;
            DEFINE TABLE IF NOT EXISTS profile SCHEMAFULL;
            DEFINE TABLE wrote TYPE RELATION IN author OUT book;
            DEFINE FIELD x ON user TYPE string;
        "#;
        let names = extract_defined_tables(sql);
        assert_eq!(names, vec!["user", "profile", "wrote"]);
    }

    #[tokio::test]
    async fn smoke_up_refresh_up_against_kv_mem() {
        use surrealdb::engine::any::connect;
        let db = connect("mem://").await.expect("mem connect");
        db.use_ns("test").use_db("test").await.expect("use ns/db");

        Migrator::up(&db, None).await.expect("first up");
        let statuses = Migrator::status(&db).await.expect("status after up");
        assert!(statuses.iter().all(|s| s.applied), "all applied after up");
        let count_after_first = statuses.len();
        assert!(count_after_first > 0, "found at least one migration");

        Migrator::refresh(&db).await.expect("refresh");
        let statuses = Migrator::status(&db).await.expect("status after refresh");
        assert!(statuses.iter().all(|s| s.applied), "all applied after refresh");

        // Second `up` is a no-op.
        Migrator::up(&db, None).await.expect("second up is no-op");
    }
}
