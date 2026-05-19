-- =============================================================================
-- 0013_usage
--   Per-call AI usage log. Drives the monthly cost dashboard, the
--   `tokens_used` / `est_cost_usd` rollups on ingestion_job, and the
--   monthly_budget_usd alarm wired off org_setting.
-- =============================================================================

DEFINE TABLE OVERWRITE token_usage SCHEMAFULL;

DEFINE FIELD OVERWRITE user              ON token_usage TYPE record<user>;
DEFINE FIELD OVERWRITE job               ON token_usage TYPE option<record<ingestion_job>>;
DEFINE FIELD OVERWRITE model             ON token_usage TYPE record<ai_model>;
DEFINE FIELD OVERWRITE prompt_tokens     ON token_usage TYPE int     DEFAULT 0;
DEFINE FIELD OVERWRITE completion_tokens ON token_usage TYPE int     DEFAULT 0;
DEFINE FIELD OVERWRITE cost_usd          ON token_usage TYPE decimal DEFAULT 0.0;
DEFINE FIELD OVERWRITE occurred_at       ON token_usage TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE token_usage_job_idx  ON token_usage COLUMNS job;
DEFINE INDEX OVERWRITE token_usage_user_idx ON token_usage COLUMNS user, occurred_at;
