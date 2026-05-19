-- =============================================================================
-- 0012_pipeline
--   The ingestion pipeline state machine. One ingestion_job per
--   "Upload → Publish" run, with side tables for the per-step progress,
--   the append-only log, the rendered PDF page cache, the AI-extracted
--   chapter drafts, and the candidate cover variants.
--
--   Also closes the cycle by adding `book.ingestion_job` (forward
--   reference: book was defined in 0004 before ingestion_job existed).
-- =============================================================================

-- ── ingestion_job (five-stage pipeline state record) ─────────────────────────
DEFINE TABLE OVERWRITE ingestion_job SCHEMAFULL;

DEFINE FIELD OVERWRITE asset              ON ingestion_job TYPE record<uploaded_asset>;
DEFINE FIELD OVERWRITE book               ON ingestion_job TYPE option<record<book>>;  -- set at publish
DEFINE FIELD OVERWRITE hint_title         ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE hint_title_ur      ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE hint_author        ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE pages              ON ingestion_job TYPE option<int>;
DEFINE FIELD OVERWRITE size_bytes         ON ingestion_job TYPE option<int>;

DEFINE FIELD OVERWRITE stage              ON ingestion_job TYPE int DEFAULT 1
    ASSERT $value >= 1 AND $value <= 5;
DEFINE FIELD OVERWRITE status             ON ingestion_job TYPE string DEFAULT "queued"
    ASSERT $value IN ["queued", "running", "paused", "failed", "completed"];

DEFINE FIELD OVERWRITE ai_provider        ON ingestion_job TYPE option<string>
    ASSERT $value = NONE OR $value IN ["claude", "openai", "google"];
DEFINE FIELD OVERWRITE ai_model           ON ingestion_job TYPE option<string>;

DEFINE FIELD OVERWRITE overall_confidence ON ingestion_job TYPE option<decimal>;
DEFINE FIELD OVERWRITE chapters_total     ON ingestion_job TYPE option<int>;
DEFINE FIELD OVERWRITE chapters_flagged   ON ingestion_job TYPE option<int>;

DEFINE FIELD OVERWRITE tokens_used        ON ingestion_job TYPE int     DEFAULT 0;
DEFINE FIELD OVERWRITE est_cost_usd       ON ingestion_job TYPE decimal DEFAULT 0.0;

DEFINE FIELD OVERWRITE cover_color        ON ingestion_job TYPE option<string>;
DEFINE FIELD OVERWRITE cover_glyph        ON ingestion_job TYPE option<string>;

DEFINE FIELD OVERWRITE created_by         ON ingestion_job TYPE record<user>;
DEFINE FIELD OVERWRITE created_at         ON ingestion_job TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at         ON ingestion_job TYPE datetime DEFAULT time::now() VALUE time::now();
DEFINE FIELD OVERWRITE completed_at       ON ingestion_job TYPE option<datetime>;

DEFINE INDEX OVERWRITE ingestion_job_status_idx ON ingestion_job COLUMNS status, stage;
DEFINE INDEX OVERWRITE ingestion_job_user_idx   ON ingestion_job COLUMNS created_by;
DEFINE INDEX OVERWRITE ingestion_job_book_idx   ON ingestion_job COLUMNS book;


-- ── pipeline_step (fixed seven rows per job; drives the "Now running" banner)
DEFINE TABLE OVERWRITE pipeline_step SCHEMAFULL;

DEFINE FIELD OVERWRITE job         ON pipeline_step TYPE record<ingestion_job>;
DEFINE FIELD OVERWRITE n           ON pipeline_step TYPE int;
DEFINE FIELD OVERWRITE label       ON pipeline_step TYPE string;
DEFINE FIELD OVERWRITE status      ON pipeline_step TYPE string DEFAULT "pending"
    ASSERT $value IN ["pending", "running", "done", "failed"];
DEFINE FIELD OVERWRITE detail      ON pipeline_step TYPE option<string>;
DEFINE FIELD OVERWRITE started_at  ON pipeline_step TYPE option<datetime>;
DEFINE FIELD OVERWRITE finished_at ON pipeline_step TYPE option<datetime>;

DEFINE INDEX OVERWRITE pipeline_step_job_idx ON pipeline_step COLUMNS job, n UNIQUE;


-- ── job_log_entry (append-only log surfaced by the JobEvents subscription) ───
DEFINE TABLE OVERWRITE job_log_entry SCHEMAFULL;

DEFINE FIELD OVERWRITE job     ON job_log_entry TYPE record<ingestion_job>;
DEFINE FIELD OVERWRITE t       ON job_log_entry TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE kind    ON job_log_entry TYPE string DEFAULT "info"
    ASSERT $value IN ["info", "ok", "warn", "err"];
DEFINE FIELD OVERWRITE message ON job_log_entry TYPE string;

DEFINE INDEX OVERWRITE job_log_entry_job_idx ON job_log_entry COLUMNS job, t;


-- ── pdf_page (per-page rendered image + OCR text cache) ──────────────────────
DEFINE TABLE OVERWRITE pdf_page SCHEMAFULL;

DEFINE FIELD OVERWRITE job             ON pdf_page TYPE record<ingestion_job>;
DEFINE FIELD OVERWRITE n               ON pdf_page TYPE int;
DEFINE FIELD OVERWRITE bucket          ON pdf_page TYPE string;
DEFINE FIELD OVERWRITE object          ON pdf_page TYPE string;       -- e.g. "jobs/{job}/pages/{n}.webp"
DEFINE FIELD OVERWRITE ocr_text        ON pdf_page TYPE option<string>;
DEFINE FIELD OVERWRITE ocr_confidence  ON pdf_page TYPE option<decimal>;
DEFINE FIELD OVERWRITE retried_count   ON pdf_page TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE rendered_at     ON pdf_page TYPE datetime DEFAULT time::now() READONLY;

DEFINE INDEX OVERWRITE pdf_page_job_n_idx ON pdf_page COLUMNS job, n UNIQUE;


-- ── chapter_draft (AI-extracted chapter, awaiting human approval) ────────────
DEFINE TABLE OVERWRITE chapter_draft SCHEMAFULL;

DEFINE FIELD OVERWRITE job                ON chapter_draft TYPE record<ingestion_job>;
DEFINE FIELD OVERWRITE n                  ON chapter_draft TYPE int;
DEFINE FIELD OVERWRITE title_ur           ON chapter_draft TYPE string;
DEFINE FIELD OVERWRITE title_en           ON chapter_draft TYPE option<string>;
DEFINE FIELD OVERWRITE page_range         ON chapter_draft TYPE string;

DEFINE FIELD OVERWRITE ai_content         ON chapter_draft TYPE string;
DEFINE FIELD OVERWRITE ai_content_format  ON chapter_draft TYPE string DEFAULT "markdown"
    ASSERT $value IN ["markdown", "html", "plaintext"];
DEFINE FIELD OVERWRITE human_content      ON chapter_draft TYPE option<string>;

DEFINE FIELD OVERWRITE ai_summary         ON chapter_draft TYPE option<string>;
DEFINE FIELD OVERWRITE themes             ON chapter_draft TYPE array<string> DEFAULT [];
DEFINE FIELD OVERWRITE entities           ON chapter_draft TYPE array<string> DEFAULT [];

DEFINE FIELD OVERWRITE confidence         ON chapter_draft TYPE decimal DEFAULT 0.0;
DEFINE FIELD OVERWRITE status             ON chapter_draft TYPE string DEFAULT "ok"
    ASSERT $value IN ["ok", "flag", "approved", "rejected"];
DEFINE FIELD OVERWRITE flag_reason        ON chapter_draft TYPE option<string>;

DEFINE FIELD OVERWRITE approved_by        ON chapter_draft TYPE option<record<user>>;
DEFINE FIELD OVERWRITE approved_at        ON chapter_draft TYPE option<datetime>;
DEFINE FIELD OVERWRITE pages_re_ocr_count ON chapter_draft TYPE int DEFAULT 0;

DEFINE FIELD OVERWRITE created_at         ON chapter_draft TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at         ON chapter_draft TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE chapter_draft_job_n_idx  ON chapter_draft COLUMNS job, n UNIQUE;
DEFINE INDEX OVERWRITE chapter_draft_status_idx ON chapter_draft COLUMNS job, status;


-- ── cover_variant (AI-generated cover candidates per job) ────────────────────
DEFINE TABLE OVERWRITE cover_variant SCHEMAFULL;

DEFINE FIELD OVERWRITE job          ON cover_variant TYPE record<ingestion_job>;
DEFINE FIELD OVERWRITE bucket       ON cover_variant TYPE string;
DEFINE FIELD OVERWRITE object       ON cover_variant TYPE string;
DEFINE FIELD OVERWRITE palette      ON cover_variant TYPE object DEFAULT {};
DEFINE FIELD OVERWRITE model        ON cover_variant TYPE option<record<ai_model>>;
DEFINE FIELD OVERWRITE prompt       ON cover_variant TYPE option<string>;
DEFINE FIELD OVERWRITE generated_at ON cover_variant TYPE datetime DEFAULT time::now() READONLY;


-- ── back-reference: book.ingestion_job ───────────────────────────────────────
-- The publish step writes this once the pipeline produces a book.
-- Lives here (rather than in 0004_book) so the target table exists first.
DEFINE FIELD OVERWRITE ingestion_job ON book TYPE option<record<ingestion_job>>;
