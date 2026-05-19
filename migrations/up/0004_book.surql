-- =============================================================================
-- 0004_book
--   Core book record + the author→book authorship edge.
--
--   Consolidates fields that used to be added across separate migrations:
--     - featured_*           (was 0005, the "editor's pick" rail)
--     - visibility, scheduled_publish_at, ingestion_job
--                            (was 0018, the publish-flow rewrite)
-- =============================================================================

-- Whitespace-only tokenizer, used by every FULLTEXT index across 0004/0005/0007.
-- Defined here (the first migration to need it) rather than its own file because
-- analyzers don't carry data and there's nothing to back-fill.
DEFINE ANALYZER OVERWRITE blank TOKENIZERS blank;

DEFINE TABLE OVERWRITE book SCHEMAFULL;

DEFINE FIELD OVERWRITE title         ON book TYPE string;
DEFINE FIELD OVERWRITE slug          ON book TYPE string;
DEFINE FIELD OVERWRITE isbn          ON book TYPE option<string>;
DEFINE FIELD OVERWRITE summary       ON book TYPE option<string>;  -- short blurb (~2-3 sentences)
DEFINE FIELD OVERWRITE description   ON book TYPE option<string>;  -- full synopsis
DEFINE FIELD OVERWRITE cover_url     ON book TYPE option<string>;
DEFINE FIELD OVERWRITE page_count    ON book TYPE option<int>;
DEFINE FIELD OVERWRITE language      ON book TYPE string DEFAULT "en";
DEFINE FIELD OVERWRITE published_at  ON book TYPE option<datetime>;
DEFINE FIELD OVERWRITE publisher     ON book TYPE option<record<publisher>>;
DEFINE FIELD OVERWRITE categories    ON book TYPE array<record<category>> DEFAULT [];
DEFINE FIELD OVERWRITE tags          ON book TYPE array<record<tag>>      DEFAULT [];

-- Denormalized rating stats. Kept in sync by the book_review event in 0007.
DEFINE FIELD OVERWRITE avg_rating    ON book TYPE option<float>;
DEFINE FIELD OVERWRITE review_count  ON book TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE chapter_count ON book TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE rating_dist   ON book TYPE object DEFAULT {};   -- { "1":0,…,"5":0 }

-- Publish flow.
--   is_published: legacy bool, kept for back-compat with older queries.
--   visibility:   richer superset (`public`/`unlisted`/`draft`).
--   scheduled_publish_at + a worker poll = "publish later" semantics.
-- The pipeline back-reference `ingestion_job` is added in migration
-- 0012 (after the target table exists), keeping this file dep-free.
DEFINE FIELD OVERWRITE is_published        ON book TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE visibility          ON book TYPE string DEFAULT "draft"
    ASSERT $value IN ["public", "unlisted", "draft"];
DEFINE FIELD OVERWRITE scheduled_publish_at ON book TYPE option<datetime>;

-- "Editor's pick" / featured rail (reader UI homepage).
DEFINE FIELD OVERWRITE featured_until    ON book TYPE option<datetime>;
DEFINE FIELD OVERWRITE featured_eyebrow  ON book TYPE option<string>;
DEFINE FIELD OVERWRITE featured_headline ON book TYPE option<string>;
DEFINE FIELD OVERWRITE featured_blurb    ON book TYPE option<string>;

DEFINE FIELD OVERWRITE created_at ON book TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at ON book TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE book_slug_idx           ON book COLUMNS slug UNIQUE;
DEFINE INDEX OVERWRITE book_isbn_idx           ON book COLUMNS isbn UNIQUE;
-- Title uses the autocomplete analyzer (defined in 0003) so partial queries
-- like "sar" still hit "Sarab". Summary stays on `blank` because long-form
-- text doesn't benefit from edge-ngrams (huge index, matches nearly everything).
DEFINE INDEX OVERWRITE book_title_search       ON book COLUMNS title   FULLTEXT ANALYZER autocomplete BM25;
DEFINE INDEX OVERWRITE book_summary_search     ON book COLUMNS summary FULLTEXT ANALYZER blank        BM25;
DEFINE INDEX OVERWRITE book_visibility_idx     ON book COLUMNS visibility;
DEFINE INDEX OVERWRITE book_schedule_idx       ON book COLUMNS scheduled_publish_at;
DEFINE INDEX OVERWRITE book_featured_until_idx ON book COLUMNS featured_until;


-- ── wrote (author → book, with role) ─────────────────────────────────────────
DEFINE TABLE OVERWRITE wrote SCHEMAFULL TYPE RELATION IN author OUT book;

DEFINE FIELD OVERWRITE role       ON wrote TYPE string DEFAULT "author"
    ASSERT $value IN ["author", "co_author", "illustrator", "editor", "translator"];
DEFINE FIELD OVERWRITE created_at ON wrote TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE wrote_unique_idx ON wrote COLUMNS in, out, role UNIQUE;
