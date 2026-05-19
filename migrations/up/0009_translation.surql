-- =============================================================================
-- 0009_translation
--   User-submitted glossary for inline word lookup. Scoped per-chapter,
--   per-book, or globally; with community ±1 voting to surface the best
--   translation per scope. An EVENT keeps the vote totals denormalized
--   on the word_translation row so list queries don't have to aggregate.
-- =============================================================================

DEFINE TABLE OVERWRITE word_translation SCHEMAFULL;

DEFINE FIELD OVERWRITE word         ON word_translation TYPE string;
DEFINE FIELD OVERWRITE translation  ON word_translation TYPE string;
DEFINE FIELD OVERWRITE source_lang  ON word_translation TYPE string;
DEFINE FIELD OVERWRITE target_lang  ON word_translation TYPE string;
DEFINE FIELD OVERWRITE submitted_by ON word_translation TYPE record<user>;
DEFINE FIELD OVERWRITE scope        ON word_translation TYPE string
    ASSERT $value IN ["global", "book", "chapter"];
DEFINE FIELD OVERWRITE book         ON word_translation TYPE option<record<book>>;
DEFINE FIELD OVERWRITE chapter      ON word_translation TYPE option<record<chapter>>;
DEFINE FIELD OVERWRITE context_note ON word_translation TYPE option<string>;
DEFINE FIELD OVERWRITE upvotes      ON word_translation TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE downvotes    ON word_translation TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE created_at   ON word_translation TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at   ON word_translation TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE word_translation_chapter_idx ON word_translation COLUMNS word, scope, chapter;
DEFINE INDEX OVERWRITE word_translation_book_idx    ON word_translation COLUMNS word, scope, book;
DEFINE INDEX OVERWRITE word_translation_global_idx  ON word_translation COLUMNS word, scope;


-- ── translation_vote (user → word_translation, ±1) ───────────────────────────
DEFINE TABLE OVERWRITE translation_vote SCHEMAFULL TYPE RELATION IN user OUT word_translation;

DEFINE FIELD OVERWRITE value      ON translation_vote TYPE int
    ASSERT $value = 1 OR $value = -1;
DEFINE FIELD OVERWRITE created_at ON translation_vote TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE translation_vote_unique_idx ON translation_vote COLUMNS in, out UNIQUE;

-- Recompute the denormalized vote counts on word_translation.
DEFINE EVENT OVERWRITE translation_vote_counts ON TABLE translation_vote
    WHEN $event = "CREATE" OR $event = "DELETE"
THEN {
    LET $wt   = $after.out ?? $before.out;
    LET $up   = (SELECT count() FROM translation_vote WHERE out = $wt AND value =  1 GROUP ALL)[0].count ?? 0;
    LET $down = (SELECT count() FROM translation_vote WHERE out = $wt AND value = -1 GROUP ALL)[0].count ?? 0;
    UPDATE $wt SET upvotes = $up, downvotes = $down;
};
