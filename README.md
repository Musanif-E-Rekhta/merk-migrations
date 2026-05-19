# merk-migrations

Schema migration runner for SurrealDB, embedded into the binary at compile time via [`rust-embed`](https://github.com/pyros2097/rust-embed).

Migration files live in `migrations/up/` and `migrations/down/` as paired `.surql` files sharing the same stem. The runner tracks applied migrations in a `_migrations` table inside your SurrealDB database.

---

## Migration file naming

```
migrations/
  up/
    0001_initial_schema.surql
    0002_rbac_graphs.surql
  down/
    0001_initial_schema.surql
    0002_rbac_graphs.surql
```

Files are sorted lexicographically by stem, so use a zero-padded numeric prefix (`0001_`, `0002_`, …) to control order. Every migration must have a file in both `up/` and `down/` with the same name — `down` runs on rollback and should undo exactly what `up` did.

---

## API

All methods take a `&Surreal<Any>` and are `async`.

### `Migrator::up(db, steps)`

Apply pending migrations. Pass `None` to apply all, or `Some(n)` to apply only the next `n`.

All migrations in a single `up` call share the same batch number, so they can be rolled back together.

```rust
use merk_migrations::Migrator;

// Apply everything pending
Migrator::up(&db, None).await?;

// Apply only the next migration
Migrator::up(&db, Some(1)).await?;
```

### `Migrator::down(db, steps)`

Roll back the last `steps` applied migrations in reverse order (default: 1). Requires a `down/<name>.surql` for each migration being rolled back.

```rust
// Roll back the last migration
Migrator::down(&db, None).await?;

// Roll back the last 3 migrations
Migrator::down(&db, Some(3)).await?;
```

### `Migrator::fresh(db)`

Drop every table in the database (via `INFO FOR DB`) and re-apply all migrations from scratch. Does not require `down/` files — it nukes everything directly. Useful in development.

```rust
Migrator::fresh(&db).await?;
```

### `Migrator::refresh(db)`

Roll back all applied migrations using their `down/` files, then re-apply all of them. Unlike `fresh`, this exercises the down path.

```rust
Migrator::refresh(&db).await?;
```

### `Migrator::status(db)`

Return a list of all known migrations with their applied state and batch number.

```rust
let statuses = Migrator::status(&db).await?;

for s in statuses {
    let state = if s.applied {
        format!("applied (batch {})", s.batch.unwrap())
    } else {
        "pending".to_string()
    };
    println!("{}: {}", s.name, state);
}
```

`MigrationStatus` fields:

| Field     | Type          | Description                          |
|-----------|---------------|--------------------------------------|
| `name`    | `String`      | Migration name (filename stem, shared by the `up/` and `down/` files) |
| `applied` | `bool`        | Whether it has been applied          |
| `batch`   | `Option<u32>` | Batch number it was applied in       |

---

## Adding a new migration

1. Create the two files (same name, one in each folder):

   ```
   migrations/up/0005_my_change.surql
   migrations/down/0005_my_change.surql
   ```

2. Write the forward schema change in `up/`:

   ```sql
   DEFINE TABLE IF NOT EXISTS my_table SCHEMALESS;
   DEFINE FIELD name ON my_table TYPE string;
   ```

3. Write the reverse in `down/`:

   ```sql
   REMOVE TABLE IF EXISTS my_table;
   ```

4. Run `Migrator::up(&db, None).await?` — only the new migration will be applied.

---

## How tracking works

The runner maintains a `_migrations` SCHEMALESS table:

```
_migrations
  name        string   — migration filename stem, e.g. "0001_initial_schema" (shared by up/ and down/ files)
  batch       u32      — batch number shared by all migrations in one up() call
  applied_at  datetime — when it was applied
```

`fresh` and `refresh` clear this table before re-running. All other tables are left untouched by `down` — only the SQL in your `down/<name>.surql` file runs.

---

## CLI

The crate ships a `migrate` binary, compiled with the `cli` feature.

### Build

```sh
cargo build -p merk-migrations --features cli
# binary: target/debug/migrate
```

### Connection

All connection flags can also be set via environment variables (`.env.local` then `.env` are loaded automatically). The names match `merk`/`merk-seed`, so a single workspace `.env.local` covers all three binaries.

| Flag | Env var | Default |
|------|---------|---------|
| `--url` | `SURREALDB_URL` | `ws://localhost:8000` |
| `--ns`  | `SURREALDB_NS`  | *(required)* |
| `--db`  | `SURREALDB_DB`  | *(required)* |
| `--user`| `SURREALDB_USER`| `root` |
| `--pass`| `SURREALDB_PASS`| `root` |

### Commands

```sh
# Apply all pending migrations
migrate --ns prod --db merk up

# Apply only the next 2 migrations
migrate --ns prod --db merk up --steps 2

# Roll back the last migration
migrate --ns prod --db merk down

# Roll back the last 3 migrations
migrate --ns prod --db merk down --steps 3

# Drop all tables and re-apply everything (dev only)
migrate --ns prod --db merk fresh

# Roll back all then re-apply all (exercises down files)
migrate --ns prod --db merk refresh

# Show applied / pending status
migrate --ns prod --db merk status
```

`status` output:

```
 Status    Batch  Name
──────────────────────────────────────────
 applied   1      0001_initial_schema
 applied   1      0002_rbac_graphs
 applied   2      0003_book_platform
 pending   -      0004_user_extensions
```

### Using a .env file

```sh
# .env.local (shared with merk + merk-seed)
SURREALDB_URL=ws://localhost:8000
SURREALDB_NS=prod
SURREALDB_DB=merk
SURREALDB_USER=root
SURREALDB_PASS=root
```

```sh
migrate up
migrate status
```

---

## Integration (used by `merk`)

```rust
use merk_migrations::Migrator;

// In your startup / db init:
Migrator::up(&db, None).await
    .map_err(|e| Error::internal("migration", e.to_string()))?;
```

##TODO:

 - create migrations
