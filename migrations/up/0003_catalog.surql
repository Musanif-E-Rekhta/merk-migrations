-- =============================================================================
-- 0003_catalog
--   Reference tables for the book catalog: people, organizations,
--   and the taxonomy used to classify books.
--
--   No record<X> references between these — they're independent
--   and can be defined in any order. Tables that DO reference them
--   (book, chapter) come in the next migrations.
-- =============================================================================

-- Autocomplete-friendly analyzer for prefix-matched search on short fields
-- (titles, names). The `class` tokenizer splits on character-class transitions
-- so punctuation and digits become token boundaries; `lowercase` + `ascii`
-- normalize case and strip diacritics; `edgengram(2,15)` generates each token's
-- 2- to 15-char prefixes so a partial query like "sar" still hits "Sarab".
-- Defined here (the first migration to need it) — see 0004's `blank` for the
-- same pattern with long-form content.
DEFINE ANALYZER OVERWRITE autocomplete
    TOKENIZERS class
    FILTERS lowercase, ascii, edgengram(2, 15);

-- ── author ───────────────────────────────────────────────────────────────────
DEFINE TABLE OVERWRITE author SCHEMAFULL;

DEFINE FIELD OVERWRITE name       ON author TYPE string;
DEFINE FIELD OVERWRITE slug       ON author TYPE string;
DEFINE FIELD OVERWRITE bio        ON author TYPE option<string>;
DEFINE FIELD OVERWRITE avatar_url ON author TYPE option<string>;
DEFINE FIELD OVERWRITE website    ON author TYPE option<string>;
DEFINE FIELD OVERWRITE born_at    ON author TYPE option<datetime>;
DEFINE FIELD OVERWRITE created_at ON author TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at ON author TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE author_slug_idx    ON author COLUMNS slug UNIQUE;
DEFINE INDEX OVERWRITE author_name_idx    ON author COLUMNS name;
DEFINE INDEX OVERWRITE author_name_search ON author COLUMNS name FULLTEXT ANALYZER autocomplete BM25;


-- ── publisher ────────────────────────────────────────────────────────────────
DEFINE TABLE OVERWRITE publisher SCHEMAFULL;

DEFINE FIELD OVERWRITE name       ON publisher TYPE string;
DEFINE FIELD OVERWRITE website    ON publisher TYPE option<string>;
DEFINE FIELD OVERWRITE country    ON publisher TYPE option<string>;
DEFINE FIELD OVERWRITE created_at ON publisher TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE publisher_name_idx ON publisher COLUMNS name UNIQUE;


-- ── category (self-referential hierarchy: Fiction > Fantasy > Epic Fantasy) ──
DEFINE TABLE OVERWRITE category SCHEMAFULL;

DEFINE FIELD OVERWRITE name        ON category TYPE string;
DEFINE FIELD OVERWRITE slug        ON category TYPE string;
DEFINE FIELD OVERWRITE description ON category TYPE option<string>;
DEFINE FIELD OVERWRITE parent      ON category TYPE option<record<category>>;
DEFINE FIELD OVERWRITE created_at  ON category TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE category_slug_idx ON category COLUMNS slug UNIQUE;


-- ── tag ──────────────────────────────────────────────────────────────────────
DEFINE TABLE OVERWRITE tag SCHEMAFULL;

DEFINE FIELD OVERWRITE name       ON tag TYPE string;
DEFINE FIELD OVERWRITE slug       ON tag TYPE string;
DEFINE FIELD OVERWRITE created_at ON tag TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE tag_slug_idx ON tag COLUMNS slug UNIQUE;
