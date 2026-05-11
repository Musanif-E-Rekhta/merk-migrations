-- =============================================================================
-- Migration 0021 (down): drop email-verification token fields
-- =============================================================================

REMOVE FIELD IF EXISTS email_verification_expires_at ON user;
REMOVE FIELD IF EXISTS email_verification_token      ON user;
