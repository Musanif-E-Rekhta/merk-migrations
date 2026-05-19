-- =============================================================================
-- 0016_option_null_to_none (down)
--   Strip the `VALUE $value ?? NONE` clauses added by the up migration,
--   restoring each `option<T>` field to its original 0001-0015 definition.
--   The data cleanup (Phase 2 of the up migration) is *not* reversed —
--   converting NONE rows back to NULL would re-introduce the coercion bug
--   that motivated this migration. Down is for schema rollback only.
-- =============================================================================

-- ── 0001_user / user ─────────────────────────────────────────────────────────
DEFINE FIELD OVERWRITE last_login                    ON user TYPE option<datetime>;
DEFINE FIELD OVERWRITE password_reset_token          ON user TYPE option<string>;
DEFINE FIELD OVERWRITE password_reset_expires_at     ON user TYPE option<datetime>;
DEFINE FIELD OVERWRITE email_verification_token      ON user TYPE option<string>;
DEFINE FIELD OVERWRITE email_verification_expires_at ON user TYPE option<datetime>;
DEFINE FIELD OVERWRITE totp_secret_enc               ON user TYPE option<string>;
DEFINE FIELD OVERWRITE totp_enabled_at               ON user TYPE option<datetime>;
DEFINE FIELD OVERWRITE totp_last_used_at             ON user TYPE option<datetime>;
DEFINE FIELD OVERWRITE totp_recovery_codes           ON user TYPE option<array<string>>;

-- ── 0001_user / profile ──────────────────────────────────────────────────────
DEFINE FIELD OVERWRITE first_name   ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE last_name    ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE display_name ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE avatar_url   ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE bio          ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE timezone     ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE phone        ON profile TYPE option<string>;
DEFINE FIELD OVERWRITE website      ON profile TYPE option<string>;

-- ── 0001_user / refresh_token ────────────────────────────────────────────────
DEFINE FIELD OVERWRITE revoked_at   ON refresh_token TYPE option<datetime>;
DEFINE FIELD OVERWRITE last_used_at ON refresh_token TYPE option<datetime>;

-- ── 0003_catalog / author ────────────────────────────────────────────────────
DEFINE FIELD OVERWRITE bio        ON author TYPE option<string>;
DEFINE FIELD OVERWRITE avatar_url ON author TYPE option<string>;
DEFINE FIELD OVERWRITE website    ON author TYPE option<string>;
DEFINE FIELD OVERWRITE born_at    ON author TYPE option<datetime>;

-- ── 0003_catalog / publisher ─────────────────────────────────────────────────
DEFINE FIELD OVERWRITE website    ON publisher TYPE option<string>;
DEFINE FIELD OVERWRITE country    ON publisher TYPE option<string>;

-- ── 0003_catalog / category ──────────────────────────────────────────────────
DEFINE FIELD OVERWRITE description ON category TYPE option<string>;
DEFINE FIELD OVERWRITE parent      ON category TYPE option<record<category>>;

-- ── 0004_book / book ─────────────────────────────────────────────────────────
DEFINE FIELD OVERWRITE isbn                 ON book TYPE option<string>;
DEFINE FIELD OVERWRITE summary              ON book TYPE option<string>;
DEFINE FIELD OVERWRITE description          ON book TYPE option<string>;
DEFINE FIELD OVERWRITE cover_url            ON book TYPE option<string>;
DEFINE FIELD OVERWRITE page_count           ON book TYPE option<int>;
DEFINE FIELD OVERWRITE published_at         ON book TYPE option<datetime>;
DEFINE FIELD OVERWRITE publisher            ON book TYPE option<record<publisher>>;
DEFINE FIELD OVERWRITE avg_rating           ON book TYPE option<float>;
DEFINE FIELD OVERWRITE scheduled_publish_at ON book TYPE option<datetime>;
DEFINE FIELD OVERWRITE featured_until       ON book TYPE option<datetime>;
DEFINE FIELD OVERWRITE featured_eyebrow     ON book TYPE option<string>;
DEFINE FIELD OVERWRITE featured_headline    ON book TYPE option<string>;
DEFINE FIELD OVERWRITE featured_blurb       ON book TYPE option<string>;

-- ── 0005_chapter / chapter ───────────────────────────────────────────────────
DEFINE FIELD OVERWRITE title             ON chapter TYPE option<string>;
DEFINE FIELD OVERWRITE summary           ON chapter TYPE option<string>;
DEFINE FIELD OVERWRITE meta_description  ON chapter TYPE option<string>;
DEFINE FIELD OVERWRITE word_count        ON chapter TYPE option<int>;
DEFINE FIELD OVERWRITE reading_time_mins ON chapter TYPE option<int>;
DEFINE FIELD OVERWRITE avg_rating        ON chapter TYPE option<float>;
DEFINE FIELD OVERWRITE published_at      ON chapter TYPE option<datetime>;
DEFINE FIELD OVERWRITE confidence        ON chapter TYPE option<decimal>;
DEFINE FIELD OVERWRITE flag_reason       ON chapter TYPE option<string>;
DEFINE FIELD OVERWRITE approved_by       ON chapter TYPE option<record<user>>;
DEFINE FIELD OVERWRITE approved_at       ON chapter TYPE option<datetime>;

-- ── 0006_reading / bookmark ──────────────────────────────────────────────────
DEFINE FIELD OVERWRITE progress     ON bookmark TYPE option<int>;
DEFINE FIELD OVERWRITE notes        ON bookmark TYPE option<string>;
DEFINE FIELD OVERWRITE started_at   ON bookmark TYPE option<datetime>;
DEFINE FIELD OVERWRITE completed_at ON bookmark TYPE option<datetime>;
DEFINE FIELD OVERWRITE last_chapter ON bookmark TYPE option<record<chapter>>;
DEFINE FIELD OVERWRITE last_offset  ON bookmark TYPE option<int>;
DEFINE FIELD OVERWRITE last_read_at ON bookmark TYPE option<datetime>;
DEFINE FIELD OVERWRITE progress_pct ON bookmark TYPE option<decimal>;

-- ── 0006_reading / reading_session ───────────────────────────────────────────
DEFINE FIELD OVERWRITE chapter       ON reading_session TYPE option<record<chapter>>;
DEFINE FIELD OVERWRITE ended_at      ON reading_session TYPE option<datetime>;
DEFINE FIELD OVERWRITE duration_mins ON reading_session TYPE option<int>;
DEFINE FIELD OVERWRITE page_end      ON reading_session TYPE option<int>;
DEFINE FIELD OVERWRITE device        ON reading_session TYPE option<string>;

-- ── 0006_reading / collection ────────────────────────────────────────────────
DEFINE FIELD OVERWRITE description ON collection TYPE option<string>;
DEFINE FIELD OVERWRITE cover_url   ON collection TYPE option<string>;

-- ── 0006_reading / collection_book ───────────────────────────────────────────
DEFINE FIELD OVERWRITE position ON collection_book TYPE option<int>;
DEFINE FIELD OVERWRITE note     ON collection_book TYPE option<string>;

-- ── 0007_reviews / book_review ───────────────────────────────────────────────
DEFINE FIELD OVERWRITE title ON book_review TYPE option<string>;
DEFINE FIELD OVERWRITE body  ON book_review TYPE option<string>;

-- ── 0007_reviews / chapter_review ────────────────────────────────────────────
DEFINE FIELD OVERWRITE body ON chapter_review TYPE option<string>;

-- ── 0007_reviews / review_flag ───────────────────────────────────────────────
DEFINE FIELD OVERWRITE note        ON review_flag TYPE option<string>;
DEFINE FIELD OVERWRITE resolved_by ON review_flag TYPE option<record<user>>;

-- ── 0008_annotations / highlight ─────────────────────────────────────────────
DEFINE FIELD OVERWRITE note ON highlight TYPE option<string>;

-- ── 0008_annotations / comment ───────────────────────────────────────────────
DEFINE FIELD OVERWRITE highlight     ON comment TYPE option<record<highlight>>;
DEFINE FIELD OVERWRITE parent        ON comment TYPE option<record<comment>>;
DEFINE FIELD OVERWRITE deleted_at    ON comment TYPE option<datetime>;
DEFINE FIELD OVERWRITE offset_start  ON comment TYPE option<int>;
DEFINE FIELD OVERWRITE offset_end    ON comment TYPE option<int>;
DEFINE FIELD OVERWRITE text_snapshot ON comment TYPE option<string>;

-- ── 0009_translation / word_translation ──────────────────────────────────────
DEFINE FIELD OVERWRITE book         ON word_translation TYPE option<record<book>>;
DEFINE FIELD OVERWRITE chapter      ON word_translation TYPE option<record<chapter>>;
DEFINE FIELD OVERWRITE context_note ON word_translation TYPE option<string>;

-- ── 0010_ai_models / ai_model ────────────────────────────────────────────────
DEFINE FIELD OVERWRITE note ON ai_model TYPE option<string>;

-- ── 0011_uploads / uploaded_asset ────────────────────────────────────────────
DEFINE FIELD OVERWRITE page_count   ON uploaded_asset TYPE option<int>;
DEFINE FIELD OVERWRITE sha256       ON uploaded_asset TYPE option<string>;
DEFINE FIELD OVERWRITE finalized_at ON uploaded_asset TYPE option<datetime>;

-- ── 0012_pipeline / ingestion_job ────────────────────────────────────────────
DEFINE FIELD OVERWRITE book               ON ingestion_job TYPE option<record<book>>;
DEFINE FIELD OVERWRITE hint_title         ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE hint_title_ur      ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE hint_author        ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE pages              ON ingestion_job TYPE option<int>;
DEFINE FIELD OVERWRITE size_bytes         ON ingestion_job TYPE option<int>;
DEFINE FIELD OVERWRITE ai_provider        ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE ai_model           ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE overall_confidence ON ingestion_job TYPE option<decimal>;
DEFINE FIELD OVERWRITE chapters_total     ON ingestion_job TYPE option<int>;
DEFINE FIELD OVERWRITE chapters_flagged   ON ingestion_job TYPE option<int>;
DEFINE FIELD OVERWRITE cover_color        ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE cover_glyph        ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE completed_at       ON ingestion_job TYPE option<datetime>;

-- ── 0012_pipeline / pipeline_step ────────────────────────────────────────────
DEFINE FIELD OVERWRITE detail      ON pipeline_step TYPE option<string>;
DEFINE FIELD OVERWRITE started_at  ON pipeline_step TYPE option<datetime>;
DEFINE FIELD OVERWRITE finished_at ON pipeline_step TYPE option<datetime>;

-- ── 0012_pipeline / pdf_page ─────────────────────────────────────────────────
DEFINE FIELD OVERWRITE ocr_text       ON pdf_page TYPE option<string>;
DEFINE FIELD OVERWRITE ocr_confidence ON pdf_page TYPE option<decimal>;

-- ── 0012_pipeline / chapter_draft ────────────────────────────────────────────
DEFINE FIELD OVERWRITE title_en      ON chapter_draft TYPE option<string>;
DEFINE FIELD OVERWRITE human_content ON chapter_draft TYPE option<string>;
DEFINE FIELD OVERWRITE ai_summary    ON chapter_draft TYPE option<string>;
DEFINE FIELD OVERWRITE flag_reason   ON chapter_draft TYPE option<string>;
DEFINE FIELD OVERWRITE approved_by   ON chapter_draft TYPE option<record<user>>;
DEFINE FIELD OVERWRITE approved_at   ON chapter_draft TYPE option<datetime>;

-- ── 0012_pipeline / cover_variant ────────────────────────────────────────────
DEFINE FIELD OVERWRITE model  ON cover_variant TYPE option<record<ai_model>>;
DEFINE FIELD OVERWRITE prompt ON cover_variant TYPE option<string>;

-- ── 0012_pipeline / book (additive) ──────────────────────────────────────────
DEFINE FIELD OVERWRITE ingestion_job ON book TYPE option<record<ingestion_job>>;

-- ── 0013_usage / token_usage ─────────────────────────────────────────────────
DEFINE FIELD OVERWRITE job ON token_usage TYPE option<record<ingestion_job>>;

-- ── 0014_search / chapter_chunk ──────────────────────────────────────────────
DEFINE FIELD OVERWRITE model ON chapter_chunk TYPE option<record<ai_model>>;

-- ── 0015_crawl / crawl_source ────────────────────────────────────────────────
DEFINE FIELD OVERWRITE default_query ON crawl_source TYPE option<object>;

-- ── 0015_crawl / crawl_run ───────────────────────────────────────────────────
DEFINE FIELD OVERWRITE finished_at     ON crawl_run TYPE option<datetime>;
DEFINE FIELD OVERWRITE last_checkpoint ON crawl_run TYPE option<object>;

-- ── 0015_crawl / crawl_target ────────────────────────────────────────────────
DEFINE FIELD OVERWRITE pdf_url           ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE pdf_sha256        ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE pdf_etag          ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE pdf_last_modified ON crawl_target TYPE option<datetime>;
DEFINE FIELD OVERWRITE size_bytes        ON crawl_target TYPE option<int>;
DEFINE FIELD OVERWRITE title_raw         ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE author_name_raw   ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE language_hint     ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE year_hint         ON crawl_target TYPE option<int>;
DEFINE FIELD OVERWRITE cover_url         ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE hints_json        ON crawl_target TYPE option<object>;
DEFINE FIELD OVERWRITE skip_reason       ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE ingest_job        ON crawl_target TYPE option<record<ingestion_job>>;
DEFINE FIELD OVERWRITE book              ON crawl_target TYPE option<record<book>>;
DEFINE FIELD OVERWRITE takedown_at       ON crawl_target TYPE option<datetime>;
DEFINE FIELD OVERWRITE error             ON crawl_target TYPE option<string>;
