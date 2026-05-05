-- =============================================================================
-- Migration 0010: Uploaded assets
--   First stop for any file an editor drops into the pipeline. The storage
--   pair (`bucket` + `object`) is portable: today it points at a local
--   filesystem path, later it points at GCS. Plan §11 will swap in GCS.
-- =============================================================================

DEFINE TABLE IF NOT EXISTS uploaded_asset SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS user         ON uploaded_asset TYPE record<user>;
DEFINE FIELD IF NOT EXISTS filename     ON uploaded_asset TYPE string;
DEFINE FIELD IF NOT EXISTS mime         ON uploaded_asset TYPE string;
DEFINE FIELD IF NOT EXISTS size_bytes   ON uploaded_asset TYPE int;
DEFINE FIELD IF NOT EXISTS bucket       ON uploaded_asset TYPE string;   -- "local" or "gs://..."
DEFINE FIELD IF NOT EXISTS object       ON uploaded_asset TYPE string;   -- key/path within bucket
DEFINE FIELD IF NOT EXISTS status       ON uploaded_asset TYPE string DEFAULT "uploading"
    ASSERT $value IN ["uploading", "ready", "failed"];
DEFINE FIELD IF NOT EXISTS page_count   ON uploaded_asset TYPE option<int>;
DEFINE FIELD IF NOT EXISTS sha256       ON uploaded_asset TYPE option<string>;
DEFINE FIELD IF NOT EXISTS created_at   ON uploaded_asset TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS finalized_at ON uploaded_asset TYPE option<datetime>;

DEFINE INDEX IF NOT EXISTS uploaded_asset_user_idx ON uploaded_asset COLUMNS user;
