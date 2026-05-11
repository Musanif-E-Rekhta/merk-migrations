-- =============================================================================
-- Migration 0011: Ingestion jobs
--   The five-stage pipeline state record. One row per "Upload → Publish" run.
-- =============================================================================

DEFINE TABLE IF NOT EXISTS ingestion_job SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS asset              ON ingestion_job TYPE record<uploaded_asset>;
DEFINE FIELD IF NOT EXISTS book               ON ingestion_job TYPE option<record<book>>;  -- set at publish
DEFINE FIELD IF NOT EXISTS hint_title         ON ingestion_job TYPE option<string>;
DEFINE FIELD IF NOT EXISTS hint_title_ur      ON ingestion_job TYPE option<string>;
DEFINE FIELD IF NOT EXISTS hint_author        ON ingestion_job TYPE option<string>;
DEFINE FIELD IF NOT EXISTS pages              ON ingestion_job TYPE option<int>;
DEFINE FIELD IF NOT EXISTS size_bytes         ON ingestion_job TYPE option<int>;

DEFINE FIELD IF NOT EXISTS stage              ON ingestion_job TYPE int DEFAULT 1
    ASSERT $value >= 1 AND $value <= 5;
DEFINE FIELD IF NOT EXISTS status             ON ingestion_job TYPE string DEFAULT "queued"
    ASSERT $value IN ["queued", "running", "paused", "failed", "completed"];

DEFINE FIELD IF NOT EXISTS ai_provider        ON ingestion_job TYPE option<string>
    ASSERT $value = NONE OR $value IN ["claude", "openai", "google"];
DEFINE FIELD IF NOT EXISTS ai_model           ON ingestion_job TYPE option<string>;

DEFINE FIELD IF NOT EXISTS overall_confidence ON ingestion_job TYPE option<decimal>;
DEFINE FIELD IF NOT EXISTS chapters_total     ON ingestion_job TYPE option<int>;
DEFINE FIELD IF NOT EXISTS chapters_flagged   ON ingestion_job TYPE option<int>;

DEFINE FIELD IF NOT EXISTS tokens_used        ON ingestion_job TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS est_cost_usd       ON ingestion_job TYPE decimal DEFAULT 0.0;

DEFINE FIELD IF NOT EXISTS cover_color        ON ingestion_job TYPE option<string>;
DEFINE FIELD IF NOT EXISTS cover_glyph        ON ingestion_job TYPE option<string>;

DEFINE FIELD IF NOT EXISTS created_by         ON ingestion_job TYPE record<user>;
DEFINE FIELD IF NOT EXISTS created_at         ON ingestion_job TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at         ON ingestion_job TYPE datetime DEFAULT time::now() VALUE time::now();
DEFINE FIELD IF NOT EXISTS completed_at       ON ingestion_job TYPE option<datetime>;

DEFINE INDEX IF NOT EXISTS ingestion_job_status_idx ON ingestion_job COLUMNS status, stage;
DEFINE INDEX IF NOT EXISTS ingestion_job_user_idx   ON ingestion_job COLUMNS created_by;
DEFINE INDEX IF NOT EXISTS ingestion_job_book_idx   ON ingestion_job COLUMNS book;
