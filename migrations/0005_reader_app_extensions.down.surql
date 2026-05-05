REMOVE INDEX IF EXISTS book_featured_until_idx ON book;
REMOVE FIELD IF EXISTS featured_blurb    ON book;
REMOVE FIELD IF EXISTS featured_headline ON book;
REMOVE FIELD IF EXISTS featured_eyebrow  ON book;
REMOVE FIELD IF EXISTS featured_until    ON book;

REMOVE INDEX IF EXISTS bookmark_last_read_idx ON bookmark;
REMOVE FIELD IF EXISTS progress_pct ON bookmark;
REMOVE FIELD IF EXISTS last_read_at ON bookmark;
REMOVE FIELD IF EXISTS last_offset  ON bookmark;
REMOVE FIELD IF EXISTS last_chapter ON bookmark;
