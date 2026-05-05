-- =============================================================================
-- Migration 0005: Reader-app extensions (B-back)
--   - bookmark: last_chapter, last_offset, last_read_at, progress_pct
--   - book:     featured_until, featured_eyebrow, featured_headline, featured_blurb
-- =============================================================================

-- BOOKMARK: extended progress tracking for the Continue Reading rail
DEFINE FIELD IF NOT EXISTS last_chapter ON bookmark TYPE option<record<chapter>>;
DEFINE FIELD IF NOT EXISTS last_offset  ON bookmark TYPE option<int>;       -- char offset within chapter
DEFINE FIELD IF NOT EXISTS last_read_at ON bookmark TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS progress_pct ON bookmark TYPE option<decimal>;   -- 0..100

-- Index for the "what am I reading right now" query, ordered by last_read_at
DEFINE INDEX IF NOT EXISTS bookmark_last_read_idx ON bookmark COLUMNS in, last_read_at;

-- BOOK: editor's pick / featured fields
DEFINE FIELD IF NOT EXISTS featured_until    ON book TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS featured_eyebrow  ON book TYPE option<string>;
DEFINE FIELD IF NOT EXISTS featured_headline ON book TYPE option<string>;
DEFINE FIELD IF NOT EXISTS featured_blurb    ON book TYPE option<string>;

-- Index lets `featured_until > time::now()` queries hit an index, not a scan
DEFINE INDEX IF NOT EXISTS book_featured_until_idx ON book COLUMNS featured_until;
