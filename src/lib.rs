use rust_embed::RustEmbed;
use serde::{Deserialize, Serialize};
use surrealdb::Surreal;
use surrealdb::engine::any::Any;
use surrealdb::types::{RecordId, SurrealValue};
use tracing::info;

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
    #[error("Failed to apply migration '{name}': {cause}")]
    Apply { name: String, cause: String },
    #[error("Failed to rollback migration '{name}': {cause}")]
    Rollback { name: String, cause: String },
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
            info!("Applying migration: {}", name);
            let sql = load_file(&format!("{}.up.surql", name))?;
            db.query(&sql).await.map_err(|e| MigrationError::Apply {
                name: name.clone(),
                cause: e.to_string(),
            })?;
            db.query(
                "CREATE _migrations SET name = $name, batch = $batch, applied_at = time::now()",
            )
            .bind(("name", name.clone()))
            .bind(("batch", batch))
            .await?;
            info!("Applied: {}", name);
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
            info!("Rolling back: {}", record.name);
            let sql = load_file(&format!("{}.down.surql", record.name))
                .map_err(|_| MigrationError::NoDownFile(record.name.clone()))?;
            db.query(&sql).await.map_err(|e| MigrationError::Rollback {
                name: record.name.clone(),
                cause: e.to_string(),
            })?;
            db.query("DELETE FROM _migrations WHERE name = $name")
                .bind(("name", record.name.clone()))
                .await?;
            info!("Rolled back: {}", record.name);
        }

        Ok(())
    }

    /// Drop all tables via `INFO FOR DB` (no down files needed), then re-apply all migrations.
    pub async fn fresh(db: &Surreal<Any>) -> Result<(), MigrationError> {
        // Two-statement query: bind info to a var, return only the table name keys.
        let mut response = db
            .query("LET $i = INFO FOR DB; RETURN object::keys($i.tables)")
            .await?;
        let table_names: Vec<String> = response.take(1).unwrap_or_default();

        for table_name in &table_names {
            if table_name != "_migrations" {
                db.query(format!("REMOVE TABLE IF EXISTS `{}`", table_name))
                    .await?;
                info!("Dropped table: {}", table_name);
            }
        }

        db.query("DELETE FROM _migrations").await?;
        info!("Database cleared, re-applying all migrations...");
        Self::up(db, None).await
    }

    /// Roll back all applied migrations via down files, then re-apply all.
    pub async fn refresh(db: &Surreal<Any>) -> Result<(), MigrationError> {
        ensure_migrations_table(db).await?;
        let count = get_applied(db).await?.len() as u32;
        if count > 0 {
            Self::down(db, Some(count)).await?;
        }
        info!("Re-applying all migrations...");
        Self::up(db, None).await
    }

    /// List all known migrations with their applied status.
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

// ── internal helpers ──────────────────────────────────────────────────────────

fn discover_migrations() -> Vec<String> {
    let mut names: std::collections::BTreeSet<String> = Default::default();
    for entry in Files::iter() {
        let path = entry.as_ref();
        if let Some(base) = path
            .strip_suffix(".up.surql")
            .or_else(|| path.strip_suffix(".down.surql"))
        {
            names.insert(base.to_string());
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
        .await?;
    Ok(())
}

async fn get_applied(db: &Surreal<Any>) -> Result<Vec<MigrationRecord>, MigrationError> {
    let mut response = db
        .query("SELECT * FROM _migrations ORDER BY name ASC")
        .await?;
    Ok(response.take(0)?)
}

async fn next_batch(db: &Surreal<Any>) -> Result<u32, MigrationError> {
    let applied = get_applied(db).await?;
    Ok(applied.iter().filter_map(|r| r.batch).max().unwrap_or(0) + 1)
}
