-- =============================================================================
-- 0001_user
--   user:    auth identity. All bolt-on user fields (password reset, plan
--            tier, TOTP 2FA, email verification) live here in one place
--            instead of being spread across follow-up migrations.
--   profile: expandable per-user profile (one row per user, enforced
--            by unique index on `user`).
--   refresh_token: hashed long-lived session tokens. Plaintext is never
--            stored — only sha256(token) goes into `token_hash`.
--
-- OVERWRITE is used throughout: re-running this migration always
-- reconciles the schema to what's defined here, even if the table was
-- previously created implicitly (SCHEMALESS TYPE ANY) by an early seed.
-- =============================================================================

-- ── user ─────────────────────────────────────────────────────────────────────
DEFINE TABLE OVERWRITE user SCHEMAFULL;

DEFINE FIELD OVERWRITE username      ON user TYPE string;
DEFINE FIELD OVERWRITE email         ON user TYPE string ASSERT string::is_email($value);
DEFINE FIELD OVERWRITE password_hash ON user TYPE string;
DEFINE FIELD OVERWRITE is_active     ON user TYPE bool     DEFAULT true;
DEFINE FIELD OVERWRITE is_verified   ON user TYPE bool     DEFAULT false;
DEFINE FIELD OVERWRITE created_at    ON user TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at    ON user TYPE datetime DEFAULT time::now() VALUE time::now();
DEFINE FIELD OVERWRITE last_login    ON user TYPE option<datetime>;
DEFINE FIELD OVERWRITE metadata      ON user TYPE object   DEFAULT {};

-- Password-reset flow (consumed by /auth/password/reset).
DEFINE FIELD OVERWRITE password_reset_token      ON user TYPE option<string>;
DEFINE FIELD OVERWRITE password_reset_expires_at ON user TYPE option<datetime>;

-- Email-verification flow (consumed by /auth/verify-email).
DEFINE FIELD OVERWRITE email_verification_token      ON user TYPE option<string>;
DEFINE FIELD OVERWRITE email_verification_expires_at ON user TYPE option<datetime>;

-- Billing tier (free | reader | patron). Drives feature gating in
-- the GraphQL layer.
DEFINE FIELD OVERWRITE plan_tier ON user TYPE string DEFAULT "free"
    ASSERT $value IN ["free", "reader", "patron"];

-- TOTP 2FA. Secret is AES-GCM encrypted at rest using a key derived
-- from JWT_SECRET; never decrypted outside the auth service.
DEFINE FIELD OVERWRITE totp_secret_enc     ON user TYPE option<string>;
DEFINE FIELD OVERWRITE totp_enabled_at     ON user TYPE option<datetime>;
DEFINE FIELD OVERWRITE totp_last_used_at   ON user TYPE option<datetime>;
DEFINE FIELD OVERWRITE totp_recovery_codes ON user TYPE option<array<string>>;

DEFINE INDEX OVERWRITE user_username_idx ON user COLUMNS username UNIQUE;
DEFINE INDEX OVERWRITE user_email_idx    ON user COLUMNS email    UNIQUE;


-- ── profile ──────────────────────────────────────────────────────────────────
DEFINE TABLE OVERWRITE profile SCHEMAFULL;

DEFINE FIELD OVERWRITE user         ON profile TYPE record<user>;
DEFINE FIELD OVERWRITE first_name   ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE last_name    ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE display_name ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE avatar_url   ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE bio          ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE language     ON profile TYPE string DEFAULT "en";
DEFINE FIELD OVERWRITE country      ON profile TYPE string DEFAULT "US";
DEFINE FIELD OVERWRITE timezone     ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE phone        ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE website      ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE created_at   ON profile TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at   ON profile TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE profile_user_idx ON profile COLUMNS user UNIQUE;


-- ── refresh_token ────────────────────────────────────────────────────────────
-- One row per logical session. Rotation issues a new row and marks the
-- old `revoked_at`; never `UPDATE`s the hash in place.
DEFINE TABLE OVERWRITE refresh_token SCHEMAFULL;

DEFINE FIELD OVERWRITE user         ON refresh_token TYPE record<user>;
DEFINE FIELD OVERWRITE token_hash   ON refresh_token TYPE string;
DEFINE FIELD OVERWRITE created_at   ON refresh_token TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE expires_at   ON refresh_token TYPE datetime;
DEFINE FIELD OVERWRITE revoked_at   ON refresh_token TYPE option<datetime>;
DEFINE FIELD OVERWRITE last_used_at ON refresh_token TYPE option<datetime>;

DEFINE INDEX OVERWRITE refresh_token_hash_idx ON refresh_token COLUMNS token_hash UNIQUE;
DEFINE INDEX OVERWRITE refresh_token_user_idx ON refresh_token COLUMNS user;
