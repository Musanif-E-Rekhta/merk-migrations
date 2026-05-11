-- =============================================================================
-- Migration 0019: Chapter provenance fields
--   Carry a few signals from chapter_draft over to the published `chapter`
--   so the reader can show "AI-extracted" badges and admins can audit.
-- =============================================================================

DEFINE FIELD IF NOT EXISTS confidence  ON chapter TYPE option<decimal>;
DEFINE FIELD IF NOT EXISTS flag_reason ON chapter TYPE option<string>;
DEFINE FIELD IF NOT EXISTS approved_by ON chapter TYPE option<record<user>>;
DEFINE FIELD IF NOT EXISTS approved_at ON chapter TYPE option<datetime>;
