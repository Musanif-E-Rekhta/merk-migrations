-- =============================================================================
-- 0014_search
--   Semantic search / RAG / recommendation substrate. Chapters get
--   chunked into ~1k-token windows; each chunk gets an embedding.
--
--   HNSW is the only remaining vector index in SurrealDB 3.x (MTREE
--   was dropped in 3.0). DIMENSION 1536 matches OpenAI
--   text-embedding-3-small / Voyage voyage-3-lite / Vertex
--   text-multilingual-embedding-002. Changing embedding models with
--   a different dimension requires a new migration that re-defines
--   this index — the chunk rows themselves don't need to change.
-- =============================================================================

DEFINE TABLE OVERWRITE chapter_chunk SCHEMAFULL;

DEFINE FIELD OVERWRITE chapter    ON chapter_chunk TYPE record<chapter>;
DEFINE FIELD OVERWRITE ord        ON chapter_chunk TYPE int;
DEFINE FIELD OVERWRITE text       ON chapter_chunk TYPE string;
DEFINE FIELD OVERWRITE embedding  ON chapter_chunk TYPE array<float>;
DEFINE FIELD OVERWRITE model      ON chapter_chunk TYPE option<record<ai_model>>;
DEFINE FIELD OVERWRITE created_at ON chapter_chunk TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE chapter_chunk_ord_idx ON chapter_chunk COLUMNS chapter, ord UNIQUE;
DEFINE INDEX OVERWRITE chapter_chunk_vec_idx ON chapter_chunk
    FIELDS embedding HNSW DIMENSION 1536 DIST COSINE TYPE F32;
