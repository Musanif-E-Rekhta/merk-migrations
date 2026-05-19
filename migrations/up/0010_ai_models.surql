-- =============================================================================
-- 0010_ai_models
--   The AI provider catalog (`ai_model`) and the singleton org-wide
--   settings row (`org_setting:singleton`, monthly budget knob).
--
--   Schema only. The actual catalog rows (Sonnet 4.6, Opus 4.7, embedding
--   models) are bootstrapped by `merk-seed::bootstrap_reference`.
--   ai_model is intentionally placed before the pipeline tables (0011+)
--   because cover_variant and chapter_chunk both reference it.
-- =============================================================================

DEFINE TABLE OVERWRITE ai_model SCHEMAFULL;

DEFINE FIELD OVERWRITE provider                ON ai_model TYPE string
    ASSERT $value IN ["claude", "openai", "google", "local"];
DEFINE FIELD OVERWRITE name                    ON ai_model TYPE string;
DEFINE FIELD OVERWRITE label                   ON ai_model TYPE string;
DEFINE FIELD OVERWRITE note                    ON ai_model TYPE option<string>;
DEFINE FIELD OVERWRITE input_cost_per_million  ON ai_model TYPE decimal DEFAULT 0.0;
DEFINE FIELD OVERWRITE output_cost_per_million ON ai_model TYPE decimal DEFAULT 0.0;
DEFINE FIELD OVERWRITE is_active               ON ai_model TYPE bool    DEFAULT true;
DEFINE FIELD OVERWRITE created_at              ON ai_model TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE ai_model_uniq ON ai_model COLUMNS provider, name UNIQUE;


-- ── org_setting (singleton, id = org_setting:singleton) ──────────────────────
DEFINE TABLE OVERWRITE org_setting SCHEMAFULL;
DEFINE FIELD OVERWRITE monthly_budget_usd ON org_setting TYPE decimal DEFAULT 100.0;
DEFINE FIELD OVERWRITE updated_at         ON org_setting TYPE datetime DEFAULT time::now() VALUE time::now();
