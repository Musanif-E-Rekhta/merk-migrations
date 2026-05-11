-- =============================================================================
-- Migration 0004: User password-reset token fields
-- =============================================================================

DEFINE FIELD IF NOT EXISTS password_reset_token      ON user TYPE option<string>;
DEFINE FIELD IF NOT EXISTS password_reset_expires_at ON user TYPE option<datetime>;
