-- =============================================================================
-- 0008_annotations
--   In-text annotations: highlights a user makes inside a chapter,
--   threaded comments on those highlights or on the chapter itself,
--   and the ±1 votes on comments.
-- =============================================================================

-- ── highlight ────────────────────────────────────────────────────────────────
-- A user selects a passage. `paragraph` is a resilience fallback in case
-- the chapter content is re-edited and the char offsets drift.
DEFINE TABLE OVERWRITE highlight SCHEMAFULL;

DEFINE FIELD OVERWRITE user          ON highlight TYPE record<user>;
DEFINE FIELD OVERWRITE book          ON highlight TYPE record<book>;
DEFINE FIELD OVERWRITE chapter       ON highlight TYPE record<chapter>;
DEFINE FIELD OVERWRITE offset_start  ON highlight TYPE int;
DEFINE FIELD OVERWRITE offset_end    ON highlight TYPE int;
DEFINE FIELD OVERWRITE paragraph     ON highlight TYPE int;
DEFINE FIELD OVERWRITE text_snapshot ON highlight TYPE string;
DEFINE FIELD OVERWRITE color         ON highlight TYPE string DEFAULT "yellow"
    ASSERT $value IN ["yellow", "green", "blue", "pink", "purple"];
DEFINE FIELD OVERWRITE note          ON highlight TYPE option<string>;
DEFINE FIELD OVERWRITE is_public     ON highlight TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE created_at    ON highlight TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at    ON highlight TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE highlight_chapter_idx ON highlight COLUMNS chapter, user;
DEFINE INDEX OVERWRITE highlight_public_idx  ON highlight COLUMNS chapter, is_public;


-- ── comment ──────────────────────────────────────────────────────────────────
-- Threaded comments anchored to a chapter. Can attach to a highlight
-- (inline social discussion), to another comment (`parent`, for replies),
-- or stand alone with their own char range (offset_start/end/text_snapshot)
-- for position-anchored chat without a saved highlight.
DEFINE TABLE OVERWRITE comment SCHEMAFULL;

DEFINE FIELD OVERWRITE user          ON comment TYPE record<user>;
DEFINE FIELD OVERWRITE book          ON comment TYPE record<book>;
DEFINE FIELD OVERWRITE chapter       ON comment TYPE record<chapter>;
DEFINE FIELD OVERWRITE highlight     ON comment TYPE option<record<highlight>>;
DEFINE FIELD OVERWRITE parent        ON comment TYPE option<record<comment>>;
DEFINE FIELD OVERWRITE body          ON comment TYPE string;
DEFINE FIELD OVERWRITE is_spoiler    ON comment TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE deleted_at    ON comment TYPE option<datetime>;   -- soft delete
DEFINE FIELD OVERWRITE offset_start  ON comment TYPE option<int>;
DEFINE FIELD OVERWRITE offset_end    ON comment TYPE option<int>;
DEFINE FIELD OVERWRITE text_snapshot ON comment TYPE option<string>;
DEFINE FIELD OVERWRITE created_at    ON comment TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at    ON comment TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE comment_chapter_idx   ON comment COLUMNS chapter;
DEFINE INDEX OVERWRITE comment_highlight_idx ON comment COLUMNS highlight;
DEFINE INDEX OVERWRITE comment_thread_idx    ON comment COLUMNS parent;
DEFINE INDEX OVERWRITE comment_user_idx      ON comment COLUMNS user;


-- ── comment_vote (user → comment, ±1) ────────────────────────────────────────
DEFINE TABLE OVERWRITE comment_vote SCHEMAFULL TYPE RELATION IN user OUT comment;

DEFINE FIELD OVERWRITE value      ON comment_vote TYPE int
    ASSERT $value = 1 OR $value = -1;
DEFINE FIELD OVERWRITE created_at ON comment_vote TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE comment_vote_unique_idx ON comment_vote COLUMNS in, out UNIQUE;
