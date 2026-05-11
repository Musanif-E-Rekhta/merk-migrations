-- =============================================================================
-- Migration 0016: Cover variants
--   Multiple AI-generated cover candidates per job. One can be `is_selected`,
--   which the publish step copies into book.cover_url.
-- =============================================================================

DEFINE TABLE IF NOT EXISTS cover_variant SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS job          ON cover_variant TYPE record<ingestion_job>;
DEFINE FIELD IF NOT EXISTS bucket       ON cover_variant TYPE string;
DEFINE FIELD IF NOT EXISTS object       ON cover_variant TYPE string;
DEFINE FIELD IF NOT EXISTS palette      ON cover_variant TYPE object DEFAULT {};
DEFINE FIELD IF NOT EXISTS model        ON cover_variant TYPE option<record<ai_model>>;
DEFINE FIELD IF NOT EXISTS prompt       ON cover_variant TYPE option<string>;
DEFINE FIELD IF NOT EXISTS generated_at ON cover_variant TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS is_selected  ON cover_variant TYPE bool DEFAULT false;

DEFINE INDEX IF NOT EXISTS cover_variant_job_idx ON cover_variant COLUMNS job, generated_at;
