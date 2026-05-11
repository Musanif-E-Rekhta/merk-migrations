-- =============================================================================
-- Migration 0006: User plan tier + 2FA scaffolding
--   - plan_tier:           billing/feature gating (default 'free')
--   - totp_secret_enc:     encrypted TOTP shared secret (AES-GCM at rest)
--   - totp_enabled_at:     when 2FA was first activated
--   - totp_last_used_at:   freshness signal for replay protection
--   - totp_recovery_codes: argon2-hashed recovery codes
-- =============================================================================

DEFINE FIELD IF NOT EXISTS plan_tier ON user TYPE string DEFAULT "free"
    ASSERT $value IN ["free", "reader", "patron"];

DEFINE FIELD IF NOT EXISTS totp_secret_enc     ON user TYPE option<string>;
DEFINE FIELD IF NOT EXISTS totp_enabled_at     ON user TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS totp_last_used_at   ON user TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS totp_recovery_codes ON user TYPE option<array<string>>;
