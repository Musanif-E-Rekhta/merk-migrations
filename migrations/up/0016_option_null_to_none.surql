-- =============================================================================
-- 0016_option_null_to_none
--   Defense-in-depth against SurrealDB's NULL-vs-NONE distinction on every
--   `option<T>` field defined across migrations 0001-0015.
--
--   Background:
--     SurrealDB's `option<T>` schema means `NONE | T`. The Rust SDK turns
--     `Option::<T>::None` into `Value::None` for direct binds, but a
--     `serde_json::Value::Null` (what `json!({"f": opt})` emits when `opt`
--     is None) is bound as `Value::Null`. Stored against `option<T>` this
--     is an illegal coercion — the engine eventually fails write/read of
--     the offending record with "Couldn't coerce value for field `f` …:
--     Expected `none | string` but found `NULL`".
--
--   Two-pronged fix:
--     1. Re-declare every `option<T>` field with `VALUE $value ?? NONE`
--        so any future bind that leaks `NULL` is silently coalesced to
--        `NONE` before coercion. This is schema-level defense regardless
--        of how the writer constructs its payload.
--     2. UPDATE every option<T> field on every record where the stored
--        value is `NULL`, replacing it with `NONE`. Existing rows that
--        were poisoned before the writer-side fix landed (`strip_nulls`
--        in `merk/src/db/mod.rs`) get cleaned in place. Phase 1 runs
--        first so the writes in phase 2 are accepted by the schema.
-- =============================================================================

-- ── 0001_user / user ─────────────────────────────────────────────────────────
DEFINE FIELD OVERWRITE last_login                    ON user TYPE option<datetime>      VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE password_reset_token          ON user TYPE option<string>        VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE password_reset_expires_at     ON user TYPE option<datetime>      VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE email_verification_token      ON user TYPE option<string>        VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE email_verification_expires_at ON user TYPE option<datetime>      VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE totp_secret_enc               ON user TYPE option<string>        VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE totp_enabled_at               ON user TYPE option<datetime>      VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE totp_last_used_at             ON user TYPE option<datetime>      VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE totp_recovery_codes           ON user TYPE option<array<string>> VALUE $value ?? NONE;

-- ── 0001_user / profile ──────────────────────────────────────────────────────
DEFINE FIELD OVERWRITE first_name   ON profile TYPE option<string> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE last_name    ON profile TYPE option<string> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE display_name ON profile TYPE option<string> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE avatar_url   ON profile TYPE option<string> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE bio          ON profile TYPE option<string> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE timezone     ON profile TYPE option<string> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE phone        ON profile TYPE option<string> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE website      ON profile TYPE option<string> VALUE $value ?? NONE;

-- ── 0001_user / refresh_token ────────────────────────────────────────────────
DEFINE FIELD OVERWRITE revoked_at   ON refresh_token TYPE option<datetime> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE last_used_at ON refresh_token TYPE option<datetime> VALUE $value ?? NONE;

-- ── 0003_catalog / author ────────────────────────────────────────────────────
DEFINE FIELD OVERWRITE bio        ON author TYPE option<string>   VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE avatar_url ON author TYPE option<string>   VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE website    ON author TYPE option<string>   VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE born_at    ON author TYPE option<datetime> VALUE $value ?? NONE;

-- ── 0003_catalog / publisher ─────────────────────────────────────────────────
DEFINE FIELD OVERWRITE website    ON publisher TYPE option<string> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE country    ON publisher TYPE option<string> VALUE $value ?? NONE;

-- ── 0003_catalog / category ──────────────────────────────────────────────────
DEFINE FIELD OVERWRITE description ON category TYPE option<string>            VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE parent      ON category TYPE option<record<category>>  VALUE $value ?? NONE;

-- ── 0004_book / book ─────────────────────────────────────────────────────────
DEFINE FIELD OVERWRITE isbn                 ON book TYPE option<string>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE summary              ON book TYPE option<string>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE description          ON book TYPE option<string>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE cover_url            ON book TYPE option<string>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE page_count           ON book TYPE option<int>                VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE published_at         ON book TYPE option<datetime>           VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE publisher            ON book TYPE option<record<publisher>>  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE avg_rating           ON book TYPE option<float>              VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE scheduled_publish_at ON book TYPE option<datetime>           VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE featured_until       ON book TYPE option<datetime>           VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE featured_eyebrow     ON book TYPE option<string>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE featured_headline    ON book TYPE option<string>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE featured_blurb       ON book TYPE option<string>             VALUE $value ?? NONE;

-- ── 0005_chapter / chapter ───────────────────────────────────────────────────
DEFINE FIELD OVERWRITE title             ON chapter TYPE option<string>          VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE summary           ON chapter TYPE option<string>          VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE meta_description  ON chapter TYPE option<string>          VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE word_count        ON chapter TYPE option<int>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE reading_time_mins ON chapter TYPE option<int>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE avg_rating        ON chapter TYPE option<float>           VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE published_at      ON chapter TYPE option<datetime>        VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE confidence        ON chapter TYPE option<decimal>         VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE flag_reason       ON chapter TYPE option<string>          VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE approved_by       ON chapter TYPE option<record<user>>    VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE approved_at       ON chapter TYPE option<datetime>        VALUE $value ?? NONE;

-- ── 0006_reading / bookmark ──────────────────────────────────────────────────
DEFINE FIELD OVERWRITE progress     ON bookmark TYPE option<int>                VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE notes        ON bookmark TYPE option<string>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE started_at   ON bookmark TYPE option<datetime>           VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE completed_at ON bookmark TYPE option<datetime>           VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE last_chapter ON bookmark TYPE option<record<chapter>>    VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE last_offset  ON bookmark TYPE option<int>                VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE last_read_at ON bookmark TYPE option<datetime>           VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE progress_pct ON bookmark TYPE option<decimal>            VALUE $value ?? NONE;

-- ── 0006_reading / reading_session ───────────────────────────────────────────
DEFINE FIELD OVERWRITE chapter       ON reading_session TYPE option<record<chapter>> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE ended_at      ON reading_session TYPE option<datetime>        VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE duration_mins ON reading_session TYPE option<int>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE page_end      ON reading_session TYPE option<int>             VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE device        ON reading_session TYPE option<string>          VALUE $value ?? NONE;

-- ── 0006_reading / collection ────────────────────────────────────────────────
DEFINE FIELD OVERWRITE description ON collection TYPE option<string> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE cover_url   ON collection TYPE option<string> VALUE $value ?? NONE;

-- ── 0006_reading / collection_book ───────────────────────────────────────────
DEFINE FIELD OVERWRITE position ON collection_book TYPE option<int>    VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE note     ON collection_book TYPE option<string> VALUE $value ?? NONE;

-- ── 0007_reviews / book_review ───────────────────────────────────────────────
DEFINE FIELD OVERWRITE title ON book_review TYPE option<string> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE body  ON book_review TYPE option<string> VALUE $value ?? NONE;

-- ── 0007_reviews / chapter_review ────────────────────────────────────────────
DEFINE FIELD OVERWRITE body ON chapter_review TYPE option<string> VALUE $value ?? NONE;

-- ── 0007_reviews / review_flag ───────────────────────────────────────────────
DEFINE FIELD OVERWRITE note        ON review_flag TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE resolved_by ON review_flag TYPE option<record<user>> VALUE $value ?? NONE;

-- ── 0008_annotations / highlight ─────────────────────────────────────────────
DEFINE FIELD OVERWRITE note ON highlight TYPE option<string> VALUE $value ?? NONE;

-- ── 0008_annotations / comment ───────────────────────────────────────────────
DEFINE FIELD OVERWRITE highlight     ON comment TYPE option<record<highlight>> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE parent        ON comment TYPE option<record<comment>>   VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE deleted_at    ON comment TYPE option<datetime>          VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE offset_start  ON comment TYPE option<int>               VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE offset_end    ON comment TYPE option<int>               VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE text_snapshot ON comment TYPE option<string>            VALUE $value ?? NONE;

-- ── 0009_translation / word_translation ──────────────────────────────────────
DEFINE FIELD OVERWRITE book         ON word_translation TYPE option<record<book>>    VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE chapter      ON word_translation TYPE option<record<chapter>> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE context_note ON word_translation TYPE option<string>          VALUE $value ?? NONE;

-- ── 0010_ai_models / ai_model ────────────────────────────────────────────────
DEFINE FIELD OVERWRITE note ON ai_model TYPE option<string> VALUE $value ?? NONE;

-- ── 0011_uploads / uploaded_asset ────────────────────────────────────────────
DEFINE FIELD OVERWRITE page_count   ON uploaded_asset TYPE option<int>      VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE sha256       ON uploaded_asset TYPE option<string>   VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE finalized_at ON uploaded_asset TYPE option<datetime> VALUE $value ?? NONE;

-- ── 0012_pipeline / ingestion_job ────────────────────────────────────────────
DEFINE FIELD OVERWRITE book               ON ingestion_job TYPE option<record<book>> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE hint_title         ON ingestion_job TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE hint_title_ur      ON ingestion_job TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE hint_author        ON ingestion_job TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE pages              ON ingestion_job TYPE option<int>          VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE size_bytes         ON ingestion_job TYPE option<int>          VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE ai_provider        ON ingestion_job TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE ai_model           ON ingestion_job TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE overall_confidence ON ingestion_job TYPE option<decimal>      VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE chapters_total     ON ingestion_job TYPE option<int>          VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE chapters_flagged   ON ingestion_job TYPE option<int>          VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE cover_color        ON ingestion_job TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE cover_glyph        ON ingestion_job TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE completed_at       ON ingestion_job TYPE option<datetime>     VALUE $value ?? NONE;

-- ── 0012_pipeline / pipeline_step ────────────────────────────────────────────
DEFINE FIELD OVERWRITE detail      ON pipeline_step TYPE option<string>   VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE started_at  ON pipeline_step TYPE option<datetime> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE finished_at ON pipeline_step TYPE option<datetime> VALUE $value ?? NONE;

-- ── 0012_pipeline / pdf_page ─────────────────────────────────────────────────
DEFINE FIELD OVERWRITE ocr_text       ON pdf_page TYPE option<string>  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE ocr_confidence ON pdf_page TYPE option<decimal> VALUE $value ?? NONE;

-- ── 0012_pipeline / chapter_draft ────────────────────────────────────────────
DEFINE FIELD OVERWRITE title_en      ON chapter_draft TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE human_content ON chapter_draft TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE ai_summary    ON chapter_draft TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE flag_reason   ON chapter_draft TYPE option<string>       VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE approved_by   ON chapter_draft TYPE option<record<user>> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE approved_at   ON chapter_draft TYPE option<datetime>     VALUE $value ?? NONE;

-- ── 0012_pipeline / cover_variant ────────────────────────────────────────────
DEFINE FIELD OVERWRITE model  ON cover_variant TYPE option<record<ai_model>> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE prompt ON cover_variant TYPE option<string>           VALUE $value ?? NONE;

-- ── 0012_pipeline / book (additive) ──────────────────────────────────────────
DEFINE FIELD OVERWRITE ingestion_job ON book TYPE option<record<ingestion_job>> VALUE $value ?? NONE;

-- ── 0013_usage / token_usage ─────────────────────────────────────────────────
DEFINE FIELD OVERWRITE job ON token_usage TYPE option<record<ingestion_job>> VALUE $value ?? NONE;

-- ── 0014_search / chapter_chunk ──────────────────────────────────────────────
DEFINE FIELD OVERWRITE model ON chapter_chunk TYPE option<record<ai_model>> VALUE $value ?? NONE;

-- ── 0015_crawl / crawl_source ────────────────────────────────────────────────
DEFINE FIELD OVERWRITE default_query ON crawl_source TYPE option<object> VALUE $value ?? NONE;

-- ── 0015_crawl / crawl_run ───────────────────────────────────────────────────
DEFINE FIELD OVERWRITE finished_at     ON crawl_run TYPE option<datetime> VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE last_checkpoint ON crawl_run TYPE option<object>   VALUE $value ?? NONE;

-- ── 0015_crawl / crawl_target ────────────────────────────────────────────────
DEFINE FIELD OVERWRITE pdf_url           ON crawl_target TYPE option<string>                  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE pdf_sha256        ON crawl_target TYPE option<string>                  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE pdf_etag          ON crawl_target TYPE option<string>                  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE pdf_last_modified ON crawl_target TYPE option<datetime>                VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE size_bytes        ON crawl_target TYPE option<int>                     VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE title_raw         ON crawl_target TYPE option<string>                  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE author_name_raw   ON crawl_target TYPE option<string>                  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE language_hint     ON crawl_target TYPE option<string>                  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE year_hint         ON crawl_target TYPE option<int>                     VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE cover_url         ON crawl_target TYPE option<string>                  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE hints_json        ON crawl_target TYPE option<object>                  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE skip_reason       ON crawl_target TYPE option<string>                  VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE ingest_job        ON crawl_target TYPE option<record<ingestion_job>>   VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE book              ON crawl_target TYPE option<record<book>>            VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE takedown_at       ON crawl_target TYPE option<datetime>                VALUE $value ?? NONE;
DEFINE FIELD OVERWRITE error             ON crawl_target TYPE option<string>                  VALUE $value ?? NONE;


-- =============================================================================
-- Phase 2: normalize stored NULLs to NONE.
--
-- For each option<T> field, set it back to itself on rows where the stored
-- value is `NULL`. The VALUE clause defined in Phase 1 coalesces the NULL
-- to NONE on write, so a re-set acts as an in-place cleanup. Targeting
-- `WHERE F = NULL` keeps unrelated rows untouched and the operation cheap.
-- =============================================================================

UPDATE user SET last_login                    = NONE WHERE last_login                    = NULL;
UPDATE user SET password_reset_token          = NONE WHERE password_reset_token          = NULL;
UPDATE user SET password_reset_expires_at     = NONE WHERE password_reset_expires_at     = NULL;
UPDATE user SET email_verification_token      = NONE WHERE email_verification_token      = NULL;
UPDATE user SET email_verification_expires_at = NONE WHERE email_verification_expires_at = NULL;
UPDATE user SET totp_secret_enc               = NONE WHERE totp_secret_enc               = NULL;
UPDATE user SET totp_enabled_at               = NONE WHERE totp_enabled_at               = NULL;
UPDATE user SET totp_last_used_at             = NONE WHERE totp_last_used_at             = NULL;
UPDATE user SET totp_recovery_codes           = NONE WHERE totp_recovery_codes           = NULL;

UPDATE profile SET first_name   = NONE WHERE first_name   = NULL;
UPDATE profile SET last_name    = NONE WHERE last_name    = NULL;
UPDATE profile SET display_name = NONE WHERE display_name = NULL;
UPDATE profile SET avatar_url   = NONE WHERE avatar_url   = NULL;
UPDATE profile SET bio          = NONE WHERE bio          = NULL;
UPDATE profile SET timezone     = NONE WHERE timezone     = NULL;
UPDATE profile SET phone        = NONE WHERE phone        = NULL;
UPDATE profile SET website      = NONE WHERE website      = NULL;

UPDATE refresh_token SET revoked_at   = NONE WHERE revoked_at   = NULL;
UPDATE refresh_token SET last_used_at = NONE WHERE last_used_at = NULL;

UPDATE author SET bio        = NONE WHERE bio        = NULL;
UPDATE author SET avatar_url = NONE WHERE avatar_url = NULL;
UPDATE author SET website    = NONE WHERE website    = NULL;
UPDATE author SET born_at    = NONE WHERE born_at    = NULL;

UPDATE publisher SET website = NONE WHERE website = NULL;
UPDATE publisher SET country = NONE WHERE country = NULL;

UPDATE category SET description = NONE WHERE description = NULL;
UPDATE category SET parent      = NONE WHERE parent      = NULL;

UPDATE book SET isbn                 = NONE WHERE isbn                 = NULL;
UPDATE book SET summary              = NONE WHERE summary              = NULL;
UPDATE book SET description          = NONE WHERE description          = NULL;
UPDATE book SET cover_url            = NONE WHERE cover_url            = NULL;
UPDATE book SET page_count           = NONE WHERE page_count           = NULL;
UPDATE book SET published_at         = NONE WHERE published_at         = NULL;
UPDATE book SET publisher            = NONE WHERE publisher            = NULL;
UPDATE book SET avg_rating           = NONE WHERE avg_rating           = NULL;
UPDATE book SET scheduled_publish_at = NONE WHERE scheduled_publish_at = NULL;
UPDATE book SET featured_until       = NONE WHERE featured_until       = NULL;
UPDATE book SET featured_eyebrow     = NONE WHERE featured_eyebrow     = NULL;
UPDATE book SET featured_headline    = NONE WHERE featured_headline    = NULL;
UPDATE book SET featured_blurb       = NONE WHERE featured_blurb       = NULL;
UPDATE book SET ingestion_job        = NONE WHERE ingestion_job        = NULL;

UPDATE chapter SET title             = NONE WHERE title             = NULL;
UPDATE chapter SET summary           = NONE WHERE summary           = NULL;
UPDATE chapter SET meta_description  = NONE WHERE meta_description  = NULL;
UPDATE chapter SET word_count        = NONE WHERE word_count        = NULL;
UPDATE chapter SET reading_time_mins = NONE WHERE reading_time_mins = NULL;
UPDATE chapter SET avg_rating        = NONE WHERE avg_rating        = NULL;
UPDATE chapter SET published_at      = NONE WHERE published_at      = NULL;
UPDATE chapter SET confidence        = NONE WHERE confidence        = NULL;
UPDATE chapter SET flag_reason       = NONE WHERE flag_reason       = NULL;
UPDATE chapter SET approved_by       = NONE WHERE approved_by       = NULL;
UPDATE chapter SET approved_at       = NONE WHERE approved_at       = NULL;

UPDATE bookmark SET progress     = NONE WHERE progress     = NULL;
UPDATE bookmark SET notes        = NONE WHERE notes        = NULL;
UPDATE bookmark SET started_at   = NONE WHERE started_at   = NULL;
UPDATE bookmark SET completed_at = NONE WHERE completed_at = NULL;
UPDATE bookmark SET last_chapter = NONE WHERE last_chapter = NULL;
UPDATE bookmark SET last_offset  = NONE WHERE last_offset  = NULL;
UPDATE bookmark SET last_read_at = NONE WHERE last_read_at = NULL;
UPDATE bookmark SET progress_pct = NONE WHERE progress_pct = NULL;

UPDATE reading_session SET chapter       = NONE WHERE chapter       = NULL;
UPDATE reading_session SET ended_at      = NONE WHERE ended_at      = NULL;
UPDATE reading_session SET duration_mins = NONE WHERE duration_mins = NULL;
UPDATE reading_session SET page_end      = NONE WHERE page_end      = NULL;
UPDATE reading_session SET device        = NONE WHERE device        = NULL;

UPDATE collection SET description = NONE WHERE description = NULL;
UPDATE collection SET cover_url   = NONE WHERE cover_url   = NULL;

UPDATE collection_book SET position = NONE WHERE position = NULL;
UPDATE collection_book SET note     = NONE WHERE note     = NULL;

UPDATE book_review SET title = NONE WHERE title = NULL;
UPDATE book_review SET body  = NONE WHERE body  = NULL;

UPDATE chapter_review SET body = NONE WHERE body = NULL;

UPDATE review_flag SET note        = NONE WHERE note        = NULL;
UPDATE review_flag SET resolved_by = NONE WHERE resolved_by = NULL;

UPDATE highlight SET note = NONE WHERE note = NULL;

UPDATE comment SET highlight     = NONE WHERE highlight     = NULL;
UPDATE comment SET parent        = NONE WHERE parent        = NULL;
UPDATE comment SET deleted_at    = NONE WHERE deleted_at    = NULL;
UPDATE comment SET offset_start  = NONE WHERE offset_start  = NULL;
UPDATE comment SET offset_end    = NONE WHERE offset_end    = NULL;
UPDATE comment SET text_snapshot = NONE WHERE text_snapshot = NULL;

UPDATE word_translation SET book         = NONE WHERE book         = NULL;
UPDATE word_translation SET chapter      = NONE WHERE chapter      = NULL;
UPDATE word_translation SET context_note = NONE WHERE context_note = NULL;

UPDATE ai_model SET note = NONE WHERE note = NULL;

UPDATE uploaded_asset SET page_count   = NONE WHERE page_count   = NULL;
UPDATE uploaded_asset SET sha256       = NONE WHERE sha256       = NULL;
UPDATE uploaded_asset SET finalized_at = NONE WHERE finalized_at = NULL;

UPDATE ingestion_job SET book               = NONE WHERE book               = NULL;
UPDATE ingestion_job SET hint_title         = NONE WHERE hint_title         = NULL;
UPDATE ingestion_job SET hint_title_ur      = NONE WHERE hint_title_ur      = NULL;
UPDATE ingestion_job SET hint_author        = NONE WHERE hint_author        = NULL;
UPDATE ingestion_job SET pages              = NONE WHERE pages              = NULL;
UPDATE ingestion_job SET size_bytes         = NONE WHERE size_bytes         = NULL;
UPDATE ingestion_job SET ai_provider        = NONE WHERE ai_provider        = NULL;
UPDATE ingestion_job SET ai_model           = NONE WHERE ai_model           = NULL;
UPDATE ingestion_job SET overall_confidence = NONE WHERE overall_confidence = NULL;
UPDATE ingestion_job SET chapters_total     = NONE WHERE chapters_total     = NULL;
UPDATE ingestion_job SET chapters_flagged   = NONE WHERE chapters_flagged   = NULL;
UPDATE ingestion_job SET cover_color        = NONE WHERE cover_color        = NULL;
UPDATE ingestion_job SET cover_glyph        = NONE WHERE cover_glyph        = NULL;
UPDATE ingestion_job SET completed_at       = NONE WHERE completed_at       = NULL;

UPDATE pipeline_step SET detail      = NONE WHERE detail      = NULL;
UPDATE pipeline_step SET started_at  = NONE WHERE started_at  = NULL;
UPDATE pipeline_step SET finished_at = NONE WHERE finished_at = NULL;

UPDATE pdf_page SET ocr_text       = NONE WHERE ocr_text       = NULL;
UPDATE pdf_page SET ocr_confidence = NONE WHERE ocr_confidence = NULL;

UPDATE chapter_draft SET title_en      = NONE WHERE title_en      = NULL;
UPDATE chapter_draft SET human_content = NONE WHERE human_content = NULL;
UPDATE chapter_draft SET ai_summary    = NONE WHERE ai_summary    = NULL;
UPDATE chapter_draft SET flag_reason   = NONE WHERE flag_reason   = NULL;
UPDATE chapter_draft SET approved_by   = NONE WHERE approved_by   = NULL;
UPDATE chapter_draft SET approved_at   = NONE WHERE approved_at   = NULL;

UPDATE cover_variant SET model  = NONE WHERE model  = NULL;
UPDATE cover_variant SET prompt = NONE WHERE prompt = NULL;

UPDATE token_usage SET job = NONE WHERE job = NULL;

UPDATE chapter_chunk SET model = NONE WHERE model = NULL;

UPDATE crawl_source SET default_query = NONE WHERE default_query = NULL;

UPDATE crawl_run SET finished_at     = NONE WHERE finished_at     = NULL;
UPDATE crawl_run SET last_checkpoint = NONE WHERE last_checkpoint = NULL;

UPDATE crawl_target SET pdf_url           = NONE WHERE pdf_url           = NULL;
UPDATE crawl_target SET pdf_sha256        = NONE WHERE pdf_sha256        = NULL;
UPDATE crawl_target SET pdf_etag          = NONE WHERE pdf_etag          = NULL;
UPDATE crawl_target SET pdf_last_modified = NONE WHERE pdf_last_modified = NULL;
UPDATE crawl_target SET size_bytes        = NONE WHERE size_bytes        = NULL;
UPDATE crawl_target SET title_raw         = NONE WHERE title_raw         = NULL;
UPDATE crawl_target SET author_name_raw   = NONE WHERE author_name_raw   = NULL;
UPDATE crawl_target SET language_hint     = NONE WHERE language_hint     = NULL;
UPDATE crawl_target SET year_hint         = NONE WHERE year_hint         = NULL;
UPDATE crawl_target SET cover_url         = NONE WHERE cover_url         = NULL;
UPDATE crawl_target SET hints_json        = NONE WHERE hints_json        = NULL;
UPDATE crawl_target SET skip_reason       = NONE WHERE skip_reason       = NULL;
UPDATE crawl_target SET ingest_job        = NONE WHERE ingest_job        = NULL;
UPDATE crawl_target SET book              = NONE WHERE book              = NULL;
UPDATE crawl_target SET takedown_at       = NONE WHERE takedown_at       = NULL;
UPDATE crawl_target SET error             = NONE WHERE error             = NULL;
