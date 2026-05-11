REMOVE INDEX IF EXISTS book_schedule_idx ON book;
REMOVE INDEX IF EXISTS book_visibility_idx ON book;
REMOVE FIELD IF EXISTS ingestion_job        ON book;
REMOVE FIELD IF EXISTS scheduled_publish_at ON book;
REMOVE FIELD IF EXISTS visibility           ON book;
