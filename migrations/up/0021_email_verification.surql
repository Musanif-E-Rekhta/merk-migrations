-- =============================================================================
-- Migration 0021: User email-verification token fields
-- =============================================================================

DEFINE FIELD IF NOT EXISTS email_verification_token      ON user TYPE option<string>;
DEFINE FIELD IF NOT EXISTS email_verification_expires_at ON user TYPE option<datetime>;
