REMOVE FIELD IF EXISTS totp_recovery_codes ON user;
REMOVE FIELD IF EXISTS totp_last_used_at   ON user;
REMOVE FIELD IF EXISTS totp_enabled_at     ON user;
REMOVE FIELD IF EXISTS totp_secret_enc     ON user;
REMOVE FIELD IF EXISTS plan_tier           ON user;
