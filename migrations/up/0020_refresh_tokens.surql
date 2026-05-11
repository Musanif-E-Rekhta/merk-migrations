-- =============================================================================
-- Migration 0020: Refresh-token sessions
--   Long-lived opaque tokens that exchange for fresh short-lived JWTs.
--   The plaintext is never stored — only its SHA-256 hash. One row per
--   logical session; rotation issues a new row and marks the old revoked.
-- =============================================================================

DEFINE TABLE IF NOT EXISTS refresh_token SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS user         ON refresh_token TYPE record<user>;
DEFINE FIELD IF NOT EXISTS token_hash   ON refresh_token TYPE string;
DEFINE FIELD IF NOT EXISTS created_at   ON refresh_token TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS expires_at   ON refresh_token TYPE datetime;
DEFINE FIELD IF NOT EXISTS revoked_at   ON refresh_token TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS last_used_at ON refresh_token TYPE option<datetime>;

DEFINE INDEX IF NOT EXISTS refresh_token_hash_idx ON refresh_token COLUMNS token_hash UNIQUE;
DEFINE INDEX IF NOT EXISTS refresh_token_user_idx ON refresh_token COLUMNS user;
