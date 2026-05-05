-- =============================================================================
-- Migration 0003: Book Reading Platform
-- Tables: author, publisher, category, tag, book, chapter,
--         bookmark, reading_session, reading_goal, collection, collection_book,
--         highlight, comment, comment_vote,
--         book_review, chapter_review, book_review_vote, chapter_review_vote,
--         review_flag, word_translation, translation_vote,
--         wrote (relation), follows (relation)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- AUTHOR
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS author SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS name       ON author TYPE string;
DEFINE FIELD IF NOT EXISTS slug       ON author TYPE string;
DEFINE FIELD IF NOT EXISTS bio        ON author TYPE option<string>;
DEFINE FIELD IF NOT EXISTS avatar_url ON author TYPE option<string>;
DEFINE FIELD IF NOT EXISTS website    ON author TYPE option<string>;
DEFINE FIELD IF NOT EXISTS born_at    ON author TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at ON author TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at ON author TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS author_slug_idx ON author COLUMNS slug UNIQUE;
DEFINE INDEX IF NOT EXISTS author_name_idx ON author COLUMNS name;


-- -----------------------------------------------------------------------------
-- PUBLISHER
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS publisher SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS name       ON publisher TYPE string;
DEFINE FIELD IF NOT EXISTS website    ON publisher TYPE option<string>;
DEFINE FIELD IF NOT EXISTS country    ON publisher TYPE option<string>;
DEFINE FIELD IF NOT EXISTS created_at ON publisher TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS publisher_name_idx ON publisher COLUMNS name UNIQUE;


-- -----------------------------------------------------------------------------
-- CATEGORY  (self-referential for hierarchy: Fiction > Fantasy > Epic Fantasy)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS category SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS name        ON category TYPE string;
DEFINE FIELD IF NOT EXISTS slug        ON category TYPE string;
DEFINE FIELD IF NOT EXISTS description ON category TYPE option<string>;
DEFINE FIELD IF NOT EXISTS parent      ON category TYPE option<record<category>>;
DEFINE FIELD IF NOT EXISTS created_at  ON category TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS category_slug_idx ON category COLUMNS slug UNIQUE;


-- -----------------------------------------------------------------------------
-- TAG
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS tag SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS name       ON tag TYPE string;
DEFINE FIELD IF NOT EXISTS slug       ON tag TYPE string;
DEFINE FIELD IF NOT EXISTS created_at ON tag TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS tag_slug_idx ON tag COLUMNS slug UNIQUE;


-- -----------------------------------------------------------------------------
-- BOOK
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS book SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS title         ON book TYPE string;
DEFINE FIELD IF NOT EXISTS slug          ON book TYPE string;
DEFINE FIELD IF NOT EXISTS isbn          ON book TYPE option<string>;
DEFINE FIELD IF NOT EXISTS summary       ON book TYPE option<string>;       -- short blurb (~2-3 sentences)
DEFINE FIELD IF NOT EXISTS description   ON book TYPE option<string>;       -- full synopsis
DEFINE FIELD IF NOT EXISTS cover_url     ON book TYPE option<string>;
DEFINE FIELD IF NOT EXISTS page_count    ON book TYPE option<int>;
DEFINE FIELD IF NOT EXISTS language      ON book TYPE string DEFAULT "en";
DEFINE FIELD IF NOT EXISTS published_at  ON book TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS publisher     ON book TYPE option<record<publisher>>;
DEFINE FIELD IF NOT EXISTS categories    ON book TYPE array<record<category>> DEFAULT [];
DEFINE FIELD IF NOT EXISTS tags          ON book TYPE array<record<tag>>      DEFAULT [];
DEFINE FIELD IF NOT EXISTS avg_rating    ON book TYPE option<float>;
DEFINE FIELD IF NOT EXISTS review_count  ON book TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS chapter_count ON book TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS rating_dist   ON book TYPE object DEFAULT {};    -- { "1":0,"2":0,"3":0,"4":0,"5":0 }
DEFINE FIELD IF NOT EXISTS is_published  ON book TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS created_at    ON book TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at    ON book TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS book_slug_idx ON book COLUMNS slug UNIQUE;
DEFINE INDEX IF NOT EXISTS book_isbn_idx ON book COLUMNS isbn UNIQUE;
DEFINE INDEX IF NOT EXISTS book_title_search ON book COLUMNS title FULLTEXT ANALYZER blank BM25;
DEFINE INDEX IF NOT EXISTS book_summary_search ON book COLUMNS summary FULLTEXT ANALYZER blank BM25;


-- -----------------------------------------------------------------------------
-- CHAPTER
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS chapter SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS book              ON chapter TYPE record<book>;
DEFINE FIELD IF NOT EXISTS number            ON chapter TYPE int;
DEFINE FIELD IF NOT EXISTS title             ON chapter TYPE option<string>;
DEFINE FIELD IF NOT EXISTS slug              ON chapter TYPE string;
DEFINE FIELD IF NOT EXISTS content          ON chapter TYPE string;
DEFINE FIELD IF NOT EXISTS content_format   ON chapter TYPE string DEFAULT "markdown"
    ASSERT $value IN ["markdown", "html", "plaintext"];
DEFINE FIELD IF NOT EXISTS summary          ON chapter TYPE option<string>;
DEFINE FIELD IF NOT EXISTS meta_description ON chapter TYPE option<string>;  -- <=160 chars, SEO
DEFINE FIELD IF NOT EXISTS word_count       ON chapter TYPE option<int>;
DEFINE FIELD IF NOT EXISTS reading_time_mins ON chapter TYPE option<int>;    -- ceil(word_count / 238)
DEFINE FIELD IF NOT EXISTS avg_rating       ON chapter TYPE option<float>;
DEFINE FIELD IF NOT EXISTS review_count     ON chapter TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS is_published     ON chapter TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS published_at     ON chapter TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at       ON chapter TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at       ON chapter TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS chapter_book_number_idx ON chapter COLUMNS book, number UNIQUE;
DEFINE INDEX IF NOT EXISTS chapter_book_slug_idx   ON chapter COLUMNS book, slug   UNIQUE;
DEFINE INDEX IF NOT EXISTS chapter_title_search ON chapter COLUMNS title FULLTEXT ANALYZER blank BM25 HIGHLIGHTS;
DEFINE INDEX IF NOT EXISTS chapter_content_search ON chapter COLUMNS content FULLTEXT ANALYZER blank BM25 HIGHLIGHTS;
DEFINE INDEX IF NOT EXISTS chapter_summary_search ON chapter COLUMNS summary FULLTEXT ANALYZER blank BM25 HIGHLIGHTS;


-- -----------------------------------------------------------------------------
-- GRAPH: wrote  (author → book, with role)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS wrote SCHEMAFULL TYPE RELATION IN author OUT book;

DEFINE FIELD IF NOT EXISTS role       ON wrote TYPE string DEFAULT "author"
    ASSERT $value IN ["author", "co_author", "illustrator", "editor", "translator"];
DEFINE FIELD IF NOT EXISTS created_at ON wrote TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS wrote_unique_idx ON wrote COLUMNS in, out, role UNIQUE;


-- -----------------------------------------------------------------------------
-- GRAPH: follows  (user → author)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS follows SCHEMAFULL TYPE RELATION IN user OUT author;

DEFINE FIELD IF NOT EXISTS created_at ON follows TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS follows_unique_idx ON follows COLUMNS in, out UNIQUE;


-- -----------------------------------------------------------------------------
-- BOOKMARK  (user → book, one per pair, tracks reading status + progress)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS bookmark SCHEMAFULL TYPE RELATION IN user OUT book;

DEFINE FIELD IF NOT EXISTS status       ON bookmark TYPE string
    ASSERT $value IN ["reading", "readlater", "completed", "dropped"];
DEFINE FIELD IF NOT EXISTS progress     ON bookmark TYPE option<int>;       -- current page
DEFINE FIELD IF NOT EXISTS notes        ON bookmark TYPE option<string>;
DEFINE FIELD IF NOT EXISTS started_at   ON bookmark TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS completed_at ON bookmark TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS created_at   ON bookmark TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at   ON bookmark TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS bookmark_unique_idx ON bookmark COLUMNS in, out UNIQUE;
DEFINE INDEX IF NOT EXISTS bookmark_status_idx ON bookmark COLUMNS in, status;


-- -----------------------------------------------------------------------------
-- READING SESSION  (append-only log; one session per sit-down)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS reading_session SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS user          ON reading_session TYPE record<user>;
DEFINE FIELD IF NOT EXISTS book          ON reading_session TYPE record<book>;
DEFINE FIELD IF NOT EXISTS chapter       ON reading_session TYPE option<record<chapter>>;
DEFINE FIELD IF NOT EXISTS started_at    ON reading_session TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS ended_at      ON reading_session TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS duration_mins ON reading_session TYPE option<int>;
DEFINE FIELD IF NOT EXISTS page_start    ON reading_session TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS page_end      ON reading_session TYPE option<int>;
DEFINE FIELD IF NOT EXISTS device        ON reading_session TYPE option<string>;  -- web | mobile | ereader

DEFINE INDEX IF NOT EXISTS session_user_book_idx ON reading_session COLUMNS user, book;
DEFINE INDEX IF NOT EXISTS session_started_idx   ON reading_session COLUMNS user, started_at;


-- -----------------------------------------------------------------------------
-- READING GOAL  (annual book count target per user)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS reading_goal SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS user      ON reading_goal TYPE record<user>;
DEFINE FIELD IF NOT EXISTS year      ON reading_goal TYPE int;
DEFINE FIELD IF NOT EXISTS target    ON reading_goal TYPE int;
DEFINE FIELD IF NOT EXISTS completed ON reading_goal TYPE int DEFAULT 0;

DEFINE INDEX IF NOT EXISTS reading_goal_unique_idx ON reading_goal COLUMNS user, year UNIQUE;


-- -----------------------------------------------------------------------------
-- COLLECTION  (user-curated book lists / shelves)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS collection SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS user        ON collection TYPE record<user>;
DEFINE FIELD IF NOT EXISTS name        ON collection TYPE string;
DEFINE FIELD IF NOT EXISTS description ON collection TYPE option<string>;
DEFINE FIELD IF NOT EXISTS cover_url   ON collection TYPE option<string>;
DEFINE FIELD IF NOT EXISTS is_public   ON collection TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS created_at  ON collection TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at  ON collection TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS collection_user_idx ON collection COLUMNS user;


-- COLLECTION → BOOK edge
DEFINE TABLE IF NOT EXISTS collection_book SCHEMAFULL TYPE RELATION IN collection OUT book;

DEFINE FIELD IF NOT EXISTS position  ON collection_book TYPE option<int>;   -- manual ordering
DEFINE FIELD IF NOT EXISTS note      ON collection_book TYPE option<string>;
DEFINE FIELD IF NOT EXISTS added_at  ON collection_book TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS collection_book_unique_idx ON collection_book COLUMNS in, out UNIQUE;


-- -----------------------------------------------------------------------------
-- HIGHLIGHT  (user selects a passage in a chapter)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS highlight SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS user          ON highlight TYPE record<user>;
DEFINE FIELD IF NOT EXISTS book          ON highlight TYPE record<book>;
DEFINE FIELD IF NOT EXISTS chapter       ON highlight TYPE record<chapter>;
DEFINE FIELD IF NOT EXISTS offset_start  ON highlight TYPE int;
DEFINE FIELD IF NOT EXISTS offset_end    ON highlight TYPE int;
DEFINE FIELD IF NOT EXISTS paragraph     ON highlight TYPE int;            -- resilience fallback
DEFINE FIELD IF NOT EXISTS text_snapshot ON highlight TYPE string;         -- copy of selected text
DEFINE FIELD IF NOT EXISTS color         ON highlight TYPE string DEFAULT "yellow"
    ASSERT $value IN ["yellow", "green", "blue", "pink", "purple"];
DEFINE FIELD IF NOT EXISTS note          ON highlight TYPE option<string>;
DEFINE FIELD IF NOT EXISTS is_public     ON highlight TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS created_at    ON highlight TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at    ON highlight TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS highlight_chapter_idx ON highlight COLUMNS chapter, user;
DEFINE INDEX IF NOT EXISTS highlight_public_idx  ON highlight COLUMNS chapter, is_public;


-- -----------------------------------------------------------------------------
-- COMMENT  (on a chapter, on a highlight, or a reply to another comment)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS comment SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS user          ON comment TYPE record<user>;
DEFINE FIELD IF NOT EXISTS book          ON comment TYPE record<book>;
DEFINE FIELD IF NOT EXISTS chapter       ON comment TYPE record<chapter>;
DEFINE FIELD IF NOT EXISTS highlight     ON comment TYPE option<record<highlight>>;  -- inline on highlight
DEFINE FIELD IF NOT EXISTS parent        ON comment TYPE option<record<comment>>;    -- threading
DEFINE FIELD IF NOT EXISTS body          ON comment TYPE string;
DEFINE FIELD IF NOT EXISTS is_spoiler    ON comment TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS deleted_at    ON comment TYPE option<datetime>;           -- soft delete
DEFINE FIELD IF NOT EXISTS created_at    ON comment TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at    ON comment TYPE datetime DEFAULT time::now() VALUE time::now();

-- Inline comment without a saved highlight (position-anchored)
DEFINE FIELD IF NOT EXISTS offset_start  ON comment TYPE option<int>;
DEFINE FIELD IF NOT EXISTS offset_end    ON comment TYPE option<int>;
DEFINE FIELD IF NOT EXISTS text_snapshot ON comment TYPE option<string>;

DEFINE INDEX IF NOT EXISTS comment_chapter_idx   ON comment COLUMNS chapter;
DEFINE INDEX IF NOT EXISTS comment_highlight_idx ON comment COLUMNS highlight;
DEFINE INDEX IF NOT EXISTS comment_thread_idx    ON comment COLUMNS parent;
DEFINE INDEX IF NOT EXISTS comment_user_idx      ON comment COLUMNS user;


-- COMMENT VOTE  (user → comment, +1 upvote / -1 downvote)
DEFINE TABLE IF NOT EXISTS comment_vote SCHEMAFULL TYPE RELATION IN user OUT comment;

DEFINE FIELD IF NOT EXISTS value      ON comment_vote TYPE int
    ASSERT $value = 1 OR $value = -1;
DEFINE FIELD IF NOT EXISTS created_at ON comment_vote TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS comment_vote_unique_idx ON comment_vote COLUMNS in, out UNIQUE;


-- -----------------------------------------------------------------------------
-- BOOK REVIEW  (user → book, one per pair)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS book_review SCHEMAFULL TYPE RELATION IN user OUT book;

DEFINE FIELD IF NOT EXISTS rating           ON book_review TYPE int
    ASSERT $value >= 1 AND $value <= 5;
DEFINE FIELD IF NOT EXISTS title            ON book_review TYPE option<string>;
DEFINE FIELD IF NOT EXISTS body             ON book_review TYPE option<string>;
DEFINE FIELD IF NOT EXISTS contains_spoiler ON book_review TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS reading_status   ON book_review TYPE string
    ASSERT $value IN ["reading", "completed", "dropped", "unread"];
DEFINE FIELD IF NOT EXISTS verified_reader  ON book_review TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS helpful_count    ON book_review TYPE int DEFAULT 0;  -- denormalized
DEFINE FIELD IF NOT EXISTS status           ON book_review TYPE string DEFAULT "published"
    ASSERT $value IN ["draft", "published", "flagged", "removed"];
DEFINE FIELD IF NOT EXISTS created_at       ON book_review TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at       ON book_review TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS book_review_unique_idx ON book_review COLUMNS in, out  UNIQUE;
DEFINE INDEX IF NOT EXISTS book_review_rating_idx ON book_review COLUMNS out, rating;
DEFINE INDEX IF NOT EXISTS book_review_status_idx ON book_review COLUMNS out, status;
DEFINE INDEX IF NOT EXISTS book_review_title_search ON book_review COLUMNS title FULLTEXT ANALYZER blank BM25;
DEFINE INDEX IF NOT EXISTS book_review_body_search ON book_review COLUMNS body FULLTEXT ANALYZER blank BM25;

-- Update book.avg_rating and book.review_count on every book_review write
DEFINE EVENT IF NOT EXISTS book_review_stats ON TABLE book_review
    WHEN $event = "CREATE" OR $event = "UPDATE" OR $event = "DELETE"
THEN {
    LET $book = $after.out ?? $before.out;
    LET $stats = (
        SELECT math::mean(rating) AS avg, count() AS total
        FROM book_review
        WHERE out = $book AND status = "published"
    )[0];
    UPDATE $book SET
        avg_rating   = $stats.avg,
        review_count = $stats.total ?? 0;
};


-- BOOK REVIEW VOTE
DEFINE TABLE IF NOT EXISTS book_review_vote SCHEMAFULL TYPE RELATION IN user OUT book_review;

DEFINE FIELD IF NOT EXISTS value      ON book_review_vote TYPE int
    ASSERT $value = 1 OR $value = -1;
DEFINE FIELD IF NOT EXISTS created_at ON book_review_vote TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS book_review_vote_unique_idx ON book_review_vote COLUMNS in, out UNIQUE;

-- Keep book_review.helpful_count in sync
DEFINE EVENT IF NOT EXISTS book_review_helpful_count ON TABLE book_review_vote
    WHEN $event = "CREATE" OR $event = "DELETE"
THEN {
    LET $review = $after.out ?? $before.out;
    LET $count  = (SELECT count() FROM book_review_vote WHERE out = $review AND value = 1)[0].count ?? 0;
    UPDATE $review SET helpful_count = $count;
};


-- -----------------------------------------------------------------------------
-- CHAPTER REVIEW  (user → chapter, one per pair)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS chapter_review SCHEMAFULL TYPE RELATION IN user OUT chapter;

DEFINE FIELD IF NOT EXISTS rating           ON chapter_review TYPE int
    ASSERT $value >= 1 AND $value <= 5;
DEFINE FIELD IF NOT EXISTS body             ON chapter_review TYPE option<string>;
DEFINE FIELD IF NOT EXISTS contains_spoiler ON chapter_review TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS helpful_count    ON chapter_review TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS status           ON chapter_review TYPE string DEFAULT "published"
    ASSERT $value IN ["draft", "published", "flagged", "removed"];
DEFINE FIELD IF NOT EXISTS created_at       ON chapter_review TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at       ON chapter_review TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS chapter_review_unique_idx ON chapter_review COLUMNS in, out UNIQUE;
DEFINE INDEX IF NOT EXISTS chapter_review_rating_idx ON chapter_review COLUMNS out, rating;

-- Update chapter.avg_rating on every chapter_review write
DEFINE EVENT IF NOT EXISTS chapter_review_stats ON TABLE chapter_review
    WHEN $event = "CREATE" OR $event = "UPDATE" OR $event = "DELETE"
THEN {
    LET $ch = $after.out ?? $before.out;
    LET $stats = (
        SELECT math::mean(rating) AS avg, count() AS total
        FROM chapter_review
        WHERE out = $ch AND status = "published"
    )[0];
    UPDATE $ch SET
        avg_rating   = $stats.avg,
        review_count = $stats.total ?? 0;
};


-- CHAPTER REVIEW VOTE
DEFINE TABLE IF NOT EXISTS chapter_review_vote SCHEMAFULL TYPE RELATION IN user OUT chapter_review;

DEFINE FIELD IF NOT EXISTS value      ON chapter_review_vote TYPE int
    ASSERT $value = 1 OR $value = -1;
DEFINE FIELD IF NOT EXISTS created_at ON chapter_review_vote TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS chapter_review_vote_unique_idx ON chapter_review_vote COLUMNS in, out UNIQUE;


-- -----------------------------------------------------------------------------
-- REVIEW FLAG  (polymorphic: flags either a book_review or chapter_review)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS review_flag SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS flagged_by   ON review_flag TYPE record<user>;
DEFINE FIELD IF NOT EXISTS review       ON review_flag TYPE record;   -- book_review:x or chapter_review:x
DEFINE FIELD IF NOT EXISTS reason       ON review_flag TYPE string
    ASSERT $value IN ["spoiler", "spam", "offensive", "inaccurate", "other"];
DEFINE FIELD IF NOT EXISTS note         ON review_flag TYPE option<string>;
DEFINE FIELD IF NOT EXISTS resolved     ON review_flag TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS resolved_by  ON review_flag TYPE option<record<user>>;
DEFINE FIELD IF NOT EXISTS created_at   ON review_flag TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS review_flag_review_idx     ON review_flag COLUMNS review;
DEFINE INDEX IF NOT EXISTS review_flag_unresolved_idx ON review_flag COLUMNS review, resolved;


-- -----------------------------------------------------------------------------
-- WORD TRANSLATION  (user-submitted glossary, scoped per chapter / book / global)
-- -----------------------------------------------------------------------------
DEFINE TABLE IF NOT EXISTS word_translation SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS word          ON word_translation TYPE string;
DEFINE FIELD IF NOT EXISTS translation   ON word_translation TYPE string;
DEFINE FIELD IF NOT EXISTS source_lang   ON word_translation TYPE string;
DEFINE FIELD IF NOT EXISTS target_lang   ON word_translation TYPE string;
DEFINE FIELD IF NOT EXISTS submitted_by  ON word_translation TYPE record<user>;
DEFINE FIELD IF NOT EXISTS scope         ON word_translation TYPE string
    ASSERT $value IN ["global", "book", "chapter"];
DEFINE FIELD IF NOT EXISTS book          ON word_translation TYPE option<record<book>>;
DEFINE FIELD IF NOT EXISTS chapter       ON word_translation TYPE option<record<chapter>>;
DEFINE FIELD IF NOT EXISTS context_note  ON word_translation TYPE option<string>;
DEFINE FIELD IF NOT EXISTS upvotes       ON word_translation TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS downvotes     ON word_translation TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS created_at    ON word_translation TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at    ON word_translation TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS wt_chapter_idx ON word_translation COLUMNS word, scope, chapter;
DEFINE INDEX IF NOT EXISTS wt_book_idx    ON word_translation COLUMNS word, scope, book;
DEFINE INDEX IF NOT EXISTS wt_global_idx  ON word_translation COLUMNS word, scope;


-- TRANSLATION VOTE
DEFINE TABLE IF NOT EXISTS translation_vote SCHEMAFULL TYPE RELATION IN user OUT word_translation;

DEFINE FIELD IF NOT EXISTS value      ON translation_vote TYPE int
    ASSERT $value = 1 OR $value = -1;
DEFINE FIELD IF NOT EXISTS created_at ON translation_vote TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS translation_vote_unique_idx ON translation_vote COLUMNS in, out UNIQUE;

-- Keep word_translation vote counts in sync
DEFINE EVENT IF NOT EXISTS translation_vote_counts ON TABLE translation_vote
    WHEN $event = "CREATE" OR $event = "DELETE"
THEN {
    LET $wt = $after.out ?? $before.out;
    LET $up   = (SELECT count() FROM translation_vote WHERE out = $wt AND value =  1)[0].count ?? 0;
    LET $down = (SELECT count() FROM translation_vote WHERE out = $wt AND value = -1)[0].count ?? 0;
    UPDATE $wt SET upvotes = $up, downvotes = $down;
};
