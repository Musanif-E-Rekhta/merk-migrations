-- =============================================================================
-- Migration 0017: Chapter chunks (semantic search / RAG / recommendations)
--   1k-token windows of chapter text + their embeddings. SurrealDB 3.0
--   dropped MTREE; HNSW is the only remaining vector index variant.
--   1536 dim matches OpenAI text-embedding-3-small / Voyage voyage-3-lite.
-- =============================================================================

DEFINE TABLE IF NOT EXISTS chapter_chunk SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS chapter   ON chapter_chunk TYPE record<chapter>;
DEFINE FIELD IF NOT EXISTS ord       ON chapter_chunk TYPE int;
DEFINE FIELD IF NOT EXISTS text      ON chapter_chunk TYPE string;
DEFINE FIELD IF NOT EXISTS embedding ON chapter_chunk TYPE array<float>;
DEFINE FIELD IF NOT EXISTS model     ON chapter_chunk TYPE option<record<ai_model>>;
DEFINE FIELD IF NOT EXISTS created_at ON chapter_chunk TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS chapter_chunk_ord_idx ON chapter_chunk COLUMNS chapter, ord UNIQUE;
DEFINE INDEX IF NOT EXISTS chapter_chunk_vec_idx ON chapter_chunk
    FIELDS embedding HNSW DIMENSION 1536 DIST COSINE TYPE F32;
