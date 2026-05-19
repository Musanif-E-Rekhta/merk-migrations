-- =============================================================================
-- 0006_reading
--   Per-user reading state: what they have on their shelf, how far they've
--   read, what curated lists they've built, and who they follow.
--
--   bookmark         user → book (one per pair) — reading status + progress
--   reading_session  user → book/chapter (append-only sit-down log)
--   reading_goal     annual book-count target
--   collection       user-curated shelf
--   collection_book  collection → book edge
--   follows          user → author edge
-- =============================================================================

-- ── bookmark ─────────────────────────────────────────────────────────────────
-- The reader's "what's on my shelf" record. RELATION so the in/out edge
-- carries the relationship; UNIQUE on (in, out) enforces one per pair.
DEFINE TABLE OVERWRITE bookmark SCHEMAFULL TYPE RELATION IN user OUT book;

DEFINE FIELD OVERWRITE status       ON bookmark TYPE string
    ASSERT $value IN ["reading", "readlater", "completed", "dropped"];
DEFINE FIELD OVERWRITE progress     ON bookmark TYPE option<int>;       -- current page
DEFINE FIELD OVERWRITE notes        ON bookmark TYPE option<string>;
DEFINE FIELD OVERWRITE started_at   ON bookmark TYPE option<datetime>;
DEFINE FIELD OVERWRITE completed_at ON bookmark TYPE option<datetime>;

-- Extended progress tracking (drives the "Continue Reading" rail).
DEFINE FIELD OVERWRITE last_chapter ON bookmark TYPE option<record<chapter>>;
DEFINE FIELD OVERWRITE last_offset  ON bookmark TYPE option<int>;       -- char offset within chapter
DEFINE FIELD OVERWRITE last_read_at ON bookmark TYPE option<datetime>;
DEFINE FIELD OVERWRITE progress_pct ON bookmark TYPE option<decimal>;   -- 0..100

DEFINE FIELD OVERWRITE created_at   ON bookmark TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at   ON bookmark TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE bookmark_unique_idx    ON bookmark COLUMNS in, out UNIQUE;
DEFINE INDEX OVERWRITE bookmark_status_idx    ON bookmark COLUMNS in, status;
DEFINE INDEX OVERWRITE bookmark_last_read_idx ON bookmark COLUMNS in, last_read_at;


-- ── reading_session (append-only, one row per sit-down) ──────────────────────
DEFINE TABLE OVERWRITE reading_session SCHEMAFULL;

DEFINE FIELD OVERWRITE user          ON reading_session TYPE record<user>;
DEFINE FIELD OVERWRITE book          ON reading_session TYPE record<book>;
DEFINE FIELD OVERWRITE chapter       ON reading_session TYPE option<record<chapter>>;
DEFINE FIELD OVERWRITE started_at    ON reading_session TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE ended_at      ON reading_session TYPE option<datetime>;
DEFINE FIELD OVERWRITE duration_mins ON reading_session TYPE option<int>;
DEFINE FIELD OVERWRITE page_start    ON reading_session TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE page_end      ON reading_session TYPE option<int>;
DEFINE FIELD OVERWRITE device        ON reading_session TYPE option<string>;  -- web | mobile | ereader

DEFINE INDEX OVERWRITE reading_session_user_book_idx ON reading_session COLUMNS user, book;
DEFINE INDEX OVERWRITE reading_session_started_idx   ON reading_session COLUMNS user, started_at;


-- ── reading_goal (annual book-count target per user) ─────────────────────────
DEFINE TABLE OVERWRITE reading_goal SCHEMAFULL;

DEFINE FIELD OVERWRITE user      ON reading_goal TYPE record<user>;
DEFINE FIELD OVERWRITE year      ON reading_goal TYPE int;
DEFINE FIELD OVERWRITE target    ON reading_goal TYPE int;
DEFINE FIELD OVERWRITE completed ON reading_goal TYPE int DEFAULT 0;

DEFINE INDEX OVERWRITE reading_goal_unique_idx ON reading_goal COLUMNS user, year UNIQUE;


-- ── collection (user-curated book list / shelf) ──────────────────────────────
DEFINE TABLE OVERWRITE collection SCHEMAFULL;

DEFINE FIELD OVERWRITE user        ON collection TYPE record<user>;
DEFINE FIELD OVERWRITE name        ON collection TYPE string;
DEFINE FIELD OVERWRITE description ON collection TYPE option<string>;
DEFINE FIELD OVERWRITE cover_url   ON collection TYPE option<string>;
DEFINE FIELD OVERWRITE is_public   ON collection TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE created_at  ON collection TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at  ON collection TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE collection_user_idx ON collection COLUMNS user;


-- ── collection_book (collection → book edge, manual ordering) ────────────────
DEFINE TABLE OVERWRITE collection_book SCHEMAFULL TYPE RELATION IN collection OUT book;

DEFINE FIELD OVERWRITE position  ON collection_book TYPE option<int>;
DEFINE FIELD OVERWRITE note      ON collection_book TYPE option<string>;
DEFINE FIELD OVERWRITE added_at  ON collection_book TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE collection_book_unique_idx ON collection_book COLUMNS in, out UNIQUE;


-- ── follows (user → author edge) ─────────────────────────────────────────────
DEFINE TABLE OVERWRITE follows SCHEMAFULL TYPE RELATION IN user OUT author;

DEFINE FIELD OVERWRITE created_at ON follows TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE follows_unique_idx ON follows COLUMNS in, out UNIQUE;
