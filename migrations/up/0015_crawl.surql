-- =============================================================================
-- 0015_crawl
--   External crawler provenance — sources, runs, targets.
--
--   The crawler is upstream of the existing ingestion pipeline: it
--   discovers PDFs on external sites, downloads them, and hands them
--   off as `uploaded_asset` + `ingestion_job` rows. These tables
--   record *provenance* — they never replace `book` / `author` /
--   `chapter`. Once a target is handed off, the existing
--   Process → Review → Edit → Publish stages take over.
--
--   See `merk/docs/crawler_rekhta_plan.md`.
-- =============================================================================

-- ── crawl_source (one row per external site we know how to crawl) ────────────
DEFINE TABLE OVERWRITE crawl_source SCHEMAFULL;

DEFINE FIELD OVERWRITE kind          ON crawl_source TYPE string;             -- "rekhta", "archive_org", "fixture"
DEFINE FIELD OVERWRITE base_url      ON crawl_source TYPE string;
DEFINE FIELD OVERWRITE enabled       ON crawl_source TYPE bool DEFAULT true;
DEFINE FIELD OVERWRITE paused        ON crawl_source TYPE bool DEFAULT false;
DEFINE FIELD OVERWRITE default_query ON crawl_source TYPE option<object>;
DEFINE FIELD OVERWRITE created_at    ON crawl_source TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at    ON crawl_source TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX OVERWRITE crawl_source_kind_idx ON crawl_source COLUMNS kind UNIQUE;


-- ── crawl_run (one row per `Crawler::run` invocation) ────────────────────────
DEFINE TABLE OVERWRITE crawl_run SCHEMAFULL;

DEFINE FIELD OVERWRITE source              ON crawl_run TYPE record<crawl_source>;
DEFINE FIELD OVERWRITE query               ON crawl_run TYPE object DEFAULT {};
DEFINE FIELD OVERWRITE started_at          ON crawl_run TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE finished_at         ON crawl_run TYPE option<datetime>;
DEFINE FIELD OVERWRITE status              ON crawl_run TYPE string DEFAULT "running"
    ASSERT $value IN ["running", "completed", "failed", "cancelled"];
DEFINE FIELD OVERWRITE candidates_seen     ON crawl_run TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE candidates_skipped  ON crawl_run TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE targets_downloaded  ON crawl_run TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE targets_handed_off  ON crawl_run TYPE int DEFAULT 0;
DEFINE FIELD OVERWRITE last_checkpoint     ON crawl_run TYPE option<object>;

DEFINE INDEX OVERWRITE crawl_run_source_idx  ON crawl_run COLUMNS source, started_at;
DEFINE INDEX OVERWRITE crawl_run_status_idx  ON crawl_run COLUMNS status;


-- ── crawl_target (one row per candidate we saw — downloaded or skipped) ──────
DEFINE TABLE OVERWRITE crawl_target SCHEMAFULL;

DEFINE FIELD OVERWRITE source             ON crawl_target TYPE record<crawl_source>;
DEFINE FIELD OVERWRITE source_url         ON crawl_target TYPE string;
DEFINE FIELD OVERWRITE pdf_url            ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE pdf_sha256         ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE pdf_etag           ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE pdf_last_modified  ON crawl_target TYPE option<datetime>;
DEFINE FIELD OVERWRITE size_bytes         ON crawl_target TYPE option<int>;

DEFINE FIELD OVERWRITE title_raw          ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE author_name_raw    ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE language_hint      ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE year_hint          ON crawl_target TYPE option<int>;
DEFINE FIELD OVERWRITE cover_url          ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE hints_json         ON crawl_target TYPE option<object>;

DEFINE FIELD OVERWRITE status             ON crawl_target TYPE string DEFAULT "new"
    ASSERT $value IN ["new", "skipped", "downloaded", "handed_off", "failed", "takedown"];
DEFINE FIELD OVERWRITE skip_reason        ON crawl_target TYPE option<string>
    ASSERT $value = NONE OR $value IN [
        "no_pdf", "paywall", "not_public_domain",
        "robots_disallowed", "already_imported",
        "drm", "unsupported_format", "other"
    ];

DEFINE FIELD OVERWRITE ingest_job         ON crawl_target TYPE option<record<ingestion_job>>;
DEFINE FIELD OVERWRITE book               ON crawl_target TYPE option<record<book>>;
DEFINE FIELD OVERWRITE takedown_at        ON crawl_target TYPE option<datetime>;

DEFINE FIELD OVERWRITE error              ON crawl_target TYPE option<string>;
DEFINE FIELD OVERWRITE attempts           ON crawl_target TYPE int DEFAULT 1;

DEFINE FIELD OVERWRITE created_at         ON crawl_target TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD OVERWRITE updated_at         ON crawl_target TYPE datetime DEFAULT time::now() VALUE time::now();

-- Dedup key 1: per-source URL uniqueness.
DEFINE INDEX OVERWRITE crawl_target_source_url_idx ON crawl_target COLUMNS source, source_url UNIQUE;
-- Dedup key 2: global SHA-256 uniqueness across sources.
DEFINE INDEX OVERWRITE crawl_target_sha_idx        ON crawl_target COLUMNS pdf_sha256 UNIQUE;
-- Operator queues.
DEFINE INDEX OVERWRITE crawl_target_status_idx     ON crawl_target COLUMNS source, status;
DEFINE INDEX OVERWRITE crawl_target_ingest_idx     ON crawl_target COLUMNS ingest_job;
