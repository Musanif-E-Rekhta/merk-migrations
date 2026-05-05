-- =============================================================================
-- Migration 0014: PDF page cache
--   Per-page rendered image + OCR text. Surfaces as the Review pane's
--   side-by-side preview (`GET /api/v1/admin/ingestion-jobs/{id}/pages/{n}.png`).
-- =============================================================================

DEFINE TABLE IF NOT EXISTS pdf_page SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS job             ON pdf_page TYPE record<ingestion_job>;
DEFINE FIELD IF NOT EXISTS n               ON pdf_page TYPE int;
DEFINE FIELD IF NOT EXISTS bucket          ON pdf_page TYPE string;
DEFINE FIELD IF NOT EXISTS object          ON pdf_page TYPE string;       -- e.g. 'jobs/{job}/pages/{n}.webp'
DEFINE FIELD IF NOT EXISTS ocr_text        ON pdf_page TYPE option<string>;
DEFINE FIELD IF NOT EXISTS ocr_confidence  ON pdf_page TYPE option<decimal>;
DEFINE FIELD IF NOT EXISTS retried_count   ON pdf_page TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS rendered_at     ON pdf_page TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS pdf_page_job_n_idx ON pdf_page COLUMNS job, n UNIQUE;
