-- =============================================================================
-- 0007_reviews
--   Book and chapter reviews, the +1/-1 votes on those reviews, and a
--   polymorphic flag table for moderation. Includes the EVENTs that
--   keep book.avg_rating / chapter.avg_rating / *.helpful_count in sync.
-- =============================================================================

-- ── book_review (user → book, one per pair) ──────────────────────────────────
DEFINE TABLE OVERWRITE book_review SCHEMAFULL TYPE RELATION IN user OUT book;

DEFINE FIELD OVERWRITE rating           ON book_review TYPE int
    ASSERT $value >= 1 AND $value <= 5;
DEFINE FIELD OVERWRITE title            ON book_review TYPE option<string>;
DEFINE FIELD OVERWRITE body             ON book_review TYPE option<string>;
DEFINE FIELD OVERWRITE contains_spoiler ON book_review TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE reading_status   ON book_review TYPE string
    ASSERT $value IN ["reading", "completed", "dropped", "unread"];
DEFINE FIELD OVERWRITE verified_reader  ON book_review TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE helpful_count    ON book_review TYPE int  DEFAULT 0;  -- denormalized
DEFINE FIELD OVERWRITE status           ON book_review TYPE string DEFAULT "published"
    ASSERT $value IN ["draft", "published", "flagged", "removed"];
DEFINE FIELD OVERWRITE created_at       ON book_review TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at       ON book_review TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE book_review_unique_idx      ON book_review COLUMNS in, out          UNIQUE;
DEFINE INDEX OVERWRITE book_review_rating_idx      ON book_review COLUMNS out, rating;
DEFINE INDEX OVERWRITE book_review_status_idx      ON book_review COLUMNS out, status;
DEFINE INDEX OVERWRITE book_review_title_search    ON book_review COLUMNS title FULLTEXT ANALYZER blank BM25;
DEFINE INDEX OVERWRITE book_review_body_search     ON book_review COLUMNS body  FULLTEXT ANALYZER blank BM25;

-- Recompute book.avg_rating / book.review_count on every write.
DEFINE EVENT OVERWRITE book_review_stats ON TABLE book_review
    WHEN $event = "CREATE" OR $event = "UPDATE" OR $event = "DELETE"
THEN {
    LET $book = $after.out ?? $before.out;
    -- GROUP ALL collapses all matching rows into a single aggregate row;
    -- without it, math::mean is evaluated per-row and rejects the scalar.
    LET $stats = (
        SELECT math::mean(rating) AS avg, count() AS total
        FROM book_review
        WHERE out = $book AND status = "published"
        GROUP ALL
    )[0];
    UPDATE $book SET
        avg_rating   = $stats.avg,
        review_count = $stats.total ?? 0;
};


-- ── book_review_vote (user → book_review, ±1) ────────────────────────────────
DEFINE TABLE OVERWRITE book_review_vote SCHEMAFULL TYPE RELATION IN user OUT book_review;

DEFINE FIELD OVERWRITE value      ON book_review_vote TYPE int
    ASSERT $value = 1 OR $value = -1;
DEFINE FIELD OVERWRITE created_at ON book_review_vote TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE book_review_vote_unique_idx ON book_review_vote COLUMNS in, out UNIQUE;

-- Keep book_review.helpful_count in sync.
DEFINE EVENT OVERWRITE book_review_helpful_count ON TABLE book_review_vote
    WHEN $event = "CREATE" OR $event = "DELETE"
THEN {
    LET $review = $after.out ?? $before.out;
    LET $count  = (SELECT count() FROM book_review_vote WHERE out = $review AND value = 1 GROUP ALL)[0].count ?? 0;
    UPDATE $review SET helpful_count = $count;
};


-- ── chapter_review (user → chapter, one per pair) ────────────────────────────
DEFINE TABLE OVERWRITE chapter_review SCHEMAFULL TYPE RELATION IN user OUT chapter;

DEFINE FIELD OVERWRITE rating           ON chapter_review TYPE int
    ASSERT $value >= 1 AND $value <= 5;
DEFINE FIELD OVERWRITE body             ON chapter_review TYPE option<string>;
DEFINE FIELD OVERWRITE contains_spoiler ON chapter_review TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE helpful_count    ON chapter_review TYPE int  DEFAULT 0;
DEFINE FIELD OVERWRITE status           ON chapter_review TYPE string DEFAULT "published"
    ASSERT $value IN ["draft", "published", "flagged", "removed"];
DEFINE FIELD OVERWRITE created_at       ON chapter_review TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at       ON chapter_review TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE chapter_review_unique_idx ON chapter_review COLUMNS in, out UNIQUE;
DEFINE INDEX OVERWRITE chapter_review_rating_idx ON chapter_review COLUMNS out, rating;

-- Recompute chapter.avg_rating / chapter.review_count on every write.
DEFINE EVENT OVERWRITE chapter_review_stats ON TABLE chapter_review
    WHEN $event = "CREATE" OR $event = "UPDATE" OR $event = "DELETE"
THEN {
    LET $ch = $after.out ?? $before.out;
    LET $stats = (
        SELECT math::mean(rating) AS avg, count() AS total
        FROM chapter_review
        WHERE out = $ch AND status = "published"
        GROUP ALL
    )[0];
    UPDATE $ch SET
        avg_rating   = $stats.avg,
        review_count = $stats.total ?? 0;
};


-- ── chapter_review_vote (user → chapter_review, ±1) ──────────────────────────
DEFINE TABLE OVERWRITE chapter_review_vote SCHEMAFULL TYPE RELATION IN user OUT chapter_review;

DEFINE FIELD OVERWRITE value      ON chapter_review_vote TYPE int
    ASSERT $value = 1 OR $value = -1;
DEFINE FIELD OVERWRITE created_at ON chapter_review_vote TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE chapter_review_vote_unique_idx ON chapter_review_vote COLUMNS in, out UNIQUE;


-- ── review_flag (polymorphic: flags either a book_review or chapter_review) ──
DEFINE TABLE OVERWRITE review_flag SCHEMAFULL;

DEFINE FIELD OVERWRITE flagged_by  ON review_flag TYPE record<user>;
-- `review` is intentionally untyped `record` (no <X>) so it can point
-- at either book_review:* or chapter_review:* without a union type.
DEFINE FIELD OVERWRITE review      ON review_flag TYPE record;
DEFINE FIELD OVERWRITE reason      ON review_flag TYPE string
    ASSERT $value IN ["spoiler", "spam", "offensive", "inaccurate", "other"];
DEFINE FIELD OVERWRITE note        ON review_flag TYPE option<string>;
DEFINE FIELD OVERWRITE resolved    ON review_flag TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE resolved_by ON review_flag TYPE option<record<user>>;
DEFINE FIELD OVERWRITE created_at  ON review_flag TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE review_flag_review_idx     ON review_flag COLUMNS review;
DEFINE INDEX OVERWRITE review_flag_unresolved_idx ON review_flag COLUMNS review, resolved;
