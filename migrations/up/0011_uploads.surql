-- =============================================================================
-- 0011_uploads
--   Uploaded assets — the first stop for any file an editor drops into
--   the pipeline. The storage pair (`bucket` + `object`) is portable:
--   today it points at a local filesystem path, later it points at GCS.
-- =============================================================================

DEFINE TABLE OVERWRITE uploaded_asset SCHEMAFULL;

DEFINE FIELD OVERWRITE user         ON uploaded_asset TYPE record<user>;
DEFINE FIELD OVERWRITE filename     ON uploaded_asset TYPE string;
DEFINE FIELD OVERWRITE mime         ON uploaded_asset TYPE string;
DEFINE FIELD OVERWRITE size_bytes   ON uploaded_asset TYPE int;
DEFINE FIELD OVERWRITE bucket       ON uploaded_asset TYPE string;   -- "local" or "gs://…"
DEFINE FIELD OVERWRITE object       ON uploaded_asset TYPE string;   -- key/path within bucket
DEFINE FIELD OVERWRITE status       ON uploaded_asset TYPE string DEFAULT "uploading"
    ASSERT $value IN ["uploading", "ready", "failed"];
DEFINE FIELD OVERWRITE page_count   ON uploaded_asset TYPE option<int>;
DEFINE FIELD OVERWRITE sha256       ON uploaded_asset TYPE option<string>;
DEFINE FIELD OVERWRITE created_at   ON uploaded_asset TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE finalized_at ON uploaded_asset TYPE option<datetime>;

DEFINE INDEX OVERWRITE uploaded_asset_user_idx ON uploaded_asset COLUMNS user;
