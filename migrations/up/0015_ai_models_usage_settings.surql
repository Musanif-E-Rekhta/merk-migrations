-- =============================================================================
-- Migration 0015: AI provider catalog + usage tracking + org settings
-- =============================================================================

DEFINE TABLE IF NOT EXISTS ai_model SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS provider                ON ai_model TYPE string
    ASSERT $value IN ["claude", "openai", "google", "local"];
DEFINE FIELD IF NOT EXISTS name                    ON ai_model TYPE string;
DEFINE FIELD IF NOT EXISTS label                   ON ai_model TYPE string;
DEFINE FIELD IF NOT EXISTS note                    ON ai_model TYPE option<string>;
DEFINE FIELD IF NOT EXISTS input_cost_per_million  ON ai_model TYPE decimal DEFAULT 0.0;
DEFINE FIELD IF NOT EXISTS output_cost_per_million ON ai_model TYPE decimal DEFAULT 0.0;
DEFINE FIELD IF NOT EXISTS is_active               ON ai_model TYPE bool DEFAULT true;
DEFINE FIELD IF NOT EXISTS created_at              ON ai_model TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS ai_model_uniq ON ai_model COLUMNS provider, name UNIQUE;


DEFINE TABLE IF NOT EXISTS token_usage SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS user              ON token_usage TYPE record<user>;
DEFINE FIELD IF NOT EXISTS job               ON token_usage TYPE option<record<ingestion_job>>;
DEFINE FIELD IF NOT EXISTS model             ON token_usage TYPE record<ai_model>;
DEFINE FIELD IF NOT EXISTS prompt_tokens     ON token_usage TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS completion_tokens ON token_usage TYPE int DEFAULT 0;
DEFINE FIELD IF NOT EXISTS cost_usd          ON token_usage TYPE decimal DEFAULT 0.0;
DEFINE FIELD IF NOT EXISTS occurred_at       ON token_usage TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX IF NOT EXISTS token_usage_job_idx  ON token_usage COLUMNS job;
DEFINE INDEX IF NOT EXISTS token_usage_user_idx ON token_usage COLUMNS user, occurred_at;


-- Singleton row keyed `org_setting:singleton`
DEFINE TABLE IF NOT EXISTS org_setting SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS monthly_budget_usd ON org_setting TYPE decimal DEFAULT 100.0;
DEFINE FIELD IF NOT EXISTS updated_at         ON org_setting TYPE datetime DEFAULT time::now() VALUE time::now();


-- Seed a few common AI models so the picker has something on day one.
CREATE ai_model:claude_sonnet_46 SET
    provider = "claude", name = "claude-sonnet-4-6",
    label = "Claude Sonnet 4.6",
    note = "Balanced quality/cost; default for chapter detection + summarization.",
    input_cost_per_million = 3.0, output_cost_per_million = 15.0;

CREATE ai_model:claude_opus_47 SET
    provider = "claude", name = "claude-opus-4-7",
    label = "Claude Opus 4.7",
    note = "Highest quality for hard texts; ~5x cost of Sonnet.",
    input_cost_per_million = 15.0, output_cost_per_million = 75.0;

CREATE ai_model:openai_gpt5 SET
    provider = "openai", name = "gpt-5",
    label = "OpenAI GPT-5",
    note = "Strong general-purpose alternative.",
    input_cost_per_million = 5.0, output_cost_per_million = 15.0;

CREATE ai_model:embed_multilingual SET
    provider = "google", name = "text-multilingual-embedding-002",
    label = "Vertex multilingual embedding",
    note = "1536-dim; default for chapter chunk embeddings.",
    input_cost_per_million = 0.025, output_cost_per_million = 0.0;

CREATE org_setting:singleton SET monthly_budget_usd = 100.0;
