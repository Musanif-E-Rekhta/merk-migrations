-- =============================================================================
-- Migration 0013: Chapter drafts
--   AI-extracted chapters that humans review and edit before publish.
--   On publish, approved drafts become real `chapter` rows.
-- =============================================================================

DEFINE TABLE IF NOT EXISTS chapter_draft SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS job                ON chapter_draft TYPE record<ingestion_job>;
DEFINE FIELD IF NOT EXISTS n                  ON chapter_draft TYPE int;
DEFINE FIELD IF NOT EXISTS title_ur           ON chapter_draft TYPE string;
DEFINE FIELD IF NOT EXISTS title_en           ON chapter_draft TYPE option<string>;
DEFINE FIELD IF NOT EXISTS page_range         ON chapter_draft TYPE string;

DEFINE FIELD IF NOT EXISTS ai_content         ON chapter_draft TYPE string;
DEFINE FIELD IF NOT EXISTS ai_content_format  ON chapter_draft TYPE string DEFAULT "markdown"
    ASSERT $value IN ["markdown", "html", "plaintext"];
DEFINE FIELD IF NOT EXISTS human_content      ON chapter_draft TYPE option<string>;

DEFINE FIELD IF NOT EXISTS ai_summary         ON chapter_draft TYPE option<string>;
DEFINE FIELD IF NOT EXISTS themes             ON chapter_draft TYPE array<string> DEFAULT [];
DEFINE FIELD IF NOT EXISTS entities           ON chapter_draft TYPE array<string> DEFAULT [];

DEFINE FIELD IF NOT EXISTS confidence         ON chapter_draft TYPE decimal DEFAULT 0.0;
DEFINE FIELD IF NOT EXISTS status             ON chapter_draft TYPE string DEFAULT "ok"
    ASSERT $value IN ["ok", "flag", "approved", "rejected"];
DEFINE FIELD IF NOT EXISTS flag_reason        ON chapter_draft TYPE option<string>;

DEFINE FIELD IF NOT EXISTS approved_by        ON chapter_draft TYPE option<record<user>>;
DEFINE FIELD IF NOT EXISTS approved_at        ON chapter_draft TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS pages_re_ocr_count ON chapter_draft TYPE int DEFAULT 0;

DEFINE FIELD IF NOT EXISTS created_at         ON chapter_draft TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at         ON chapter_draft TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS chapter_draft_job_n_idx ON chapter_draft COLUMNS job, n UNIQUE;
DEFINE INDEX IF NOT EXISTS chapter_draft_status_idx ON chapter_draft COLUMNS job, status;
