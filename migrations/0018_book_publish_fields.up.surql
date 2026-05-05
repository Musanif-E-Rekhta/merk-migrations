-- =============================================================================
-- Migration 0018: Publish-flow fields on book
--   Layered on the existing is_published bool: visibility is the richer
--   superset, scheduled_publish_at supports "publish later", ingestion_job
--   is provenance back to the pipeline run that created this book.
-- =============================================================================

DEFINE FIELD IF NOT EXISTS visibility           ON book TYPE string DEFAULT "draft"
    ASSERT $value IN ["public", "unlisted", "draft"];
DEFINE FIELD IF NOT EXISTS scheduled_publish_at ON book TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS ingestion_job        ON book TYPE option<record<ingestion_job>>;

DEFINE INDEX IF NOT EXISTS book_visibility_idx ON book COLUMNS visibility;
DEFINE INDEX IF NOT EXISTS book_schedule_idx   ON book COLUMNS scheduled_publish_at;
