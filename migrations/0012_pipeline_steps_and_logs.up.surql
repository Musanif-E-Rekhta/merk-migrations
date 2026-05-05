-- =============================================================================
-- Migration 0012: Pipeline step tracking + per-job log
--   pipeline_step: fixed seven rows per job (PDF parse, OCR, chapter detect,
--   summarization, embeddings, cover, QA). Live "Now running" banner reads here.
--   job_log_entry: append-only log surfaced by the JobEvents subscription.
-- =============================================================================

DEFINE TABLE IF NOT EXISTS pipeline_step SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS job         ON pipeline_step TYPE record<ingestion_job>;
DEFINE FIELD IF NOT EXISTS n           ON pipeline_step TYPE int;
DEFINE FIELD IF NOT EXISTS label       ON pipeline_step TYPE string;
DEFINE FIELD IF NOT EXISTS status      ON pipeline_step TYPE string DEFAULT "pending"
    ASSERT $value IN ["pending", "running", "done", "failed"];
DEFINE FIELD IF NOT EXISTS detail      ON pipeline_step TYPE option<string>;
DEFINE FIELD IF NOT EXISTS started_at  ON pipeline_step TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS finished_at ON pipeline_step TYPE option<datetime>;

DEFINE INDEX IF NOT EXISTS pipeline_step_job_idx ON pipeline_step COLUMNS job, n UNIQUE;


DEFINE TABLE IF NOT EXISTS job_log_entry SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS job     ON job_log_entry TYPE record<ingestion_job>;
DEFINE FIELD IF NOT EXISTS t       ON job_log_entry TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS kind    ON job_log_entry TYPE string DEFAULT "info"
    ASSERT $value IN ["info", "ok", "warn", "err"];
DEFINE FIELD IF NOT EXISTS message ON job_log_entry TYPE string;

DEFINE INDEX IF NOT EXISTS job_log_entry_job_idx ON job_log_entry COLUMNS job, t;
