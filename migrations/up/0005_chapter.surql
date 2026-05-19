-- =============================================================================
-- 0005_chapter
--   Chapter rows belong to a book. Provenance fields carry forward
--   the AI-extraction signals from chapter_draft (0016) so the reader
--   can show "AI-extracted" badges and admins can audit.
-- =============================================================================

DEFINE TABLE OVERWRITE chapter SCHEMAFULL;

DEFINE FIELD OVERWRITE book              ON chapter TYPE record<book>;
DEFINE FIELD OVERWRITE number            ON chapter TYPE int;
DEFINE FIELD OVERWRITE title             ON chapter TYPE option<string>;
DEFINE FIELD OVERWRITE slug              ON chapter TYPE string;
DEFINE FIELD OVERWRITE content           ON chapter TYPE string;
DEFINE FIELD OVERWRITE content_format    ON chapter TYPE string DEFAULT "markdown"
    ASSERT $value IN ["markdown", "html", "plaintext"];
DEFINE FIELD OVERWRITE summary           ON chapter TYPE option<string>;
DEFINE FIELD OVERWRITE meta_description  ON chapter TYPE option<string>;  -- ≤160 chars, SEO
DEFINE FIELD OVERWRITE word_count        ON chapter TYPE option<int>;
DEFINE FIELD OVERWRITE reading_time_mins ON chapter TYPE option<int>;     -- ceil(word_count / 238)
DEFINE FIELD OVERWRITE avg_rating        ON chapter TYPE option<float>;
DEFINE FIELD OVERWRITE review_count      ON chapter TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE is_published      ON chapter TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE published_at      ON chapter TYPE option<datetime>;

-- Provenance — populated when an ingestion job promotes a chapter_draft.
DEFINE FIELD OVERWRITE confidence        ON chapter TYPE option<decimal>;
DEFINE FIELD OVERWRITE flag_reason       ON chapter TYPE option<string>;
DEFINE FIELD OVERWRITE approved_by       ON chapter TYPE option<record<user>>;
DEFINE FIELD OVERWRITE approved_at       ON chapter TYPE option<datetime>;

DEFINE FIELD OVERWRITE created_at        ON chapter TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at        ON chapter TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE chapter_book_number_idx ON chapter COLUMNS book, number UNIQUE;
DEFINE INDEX OVERWRITE chapter_book_slug_idx   ON chapter COLUMNS book, slug   UNIQUE;
DEFINE INDEX OVERWRITE chapter_title_search    ON chapter COLUMNS title   FULLTEXT ANALYZER blank BM25 HIGHLIGHTS;
DEFINE INDEX OVERWRITE chapter_content_search  ON chapter COLUMNS content FULLTEXT ANALYZER blank BM25 HIGHLIGHTS;
DEFINE INDEX OVERWRITE chapter_summary_search  ON chapter COLUMNS summary FULLTEXT ANALYZER blank BM25 HIGHLIGHTS;
