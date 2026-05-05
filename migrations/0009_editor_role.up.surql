-- =============================================================================
-- Migration 0009: Editor role + admin permissions
--   Builds on the 0002 RBAC graph: role / permission / assigned_role / has_permission.
--   Admin middleware resolves caller -> assigned_role -> role and gates
--   /api/v1/admin/* + the admin GraphQL surface.
-- =============================================================================

-- Permissions used by the admin pipeline.
CREATE permission:admin_jobs       SET name = "admin:jobs";
CREATE permission:admin_drafts     SET name = "admin:drafts";
CREATE permission:admin_publish    SET name = "admin:publish";
CREATE permission:admin_library    SET name = "admin:library";
CREATE permission:admin_authors    SET name = "admin:authors";
CREATE permission:admin_ai         SET name = "admin:ai";
CREATE permission:admin_uploads    SET name = "admin:uploads";

-- Editor role gets all admin permissions.
CREATE role:editor SET name = "editor";
RELATE role:editor->has_permission->permission:admin_jobs;
RELATE role:editor->has_permission->permission:admin_drafts;
RELATE role:editor->has_permission->permission:admin_publish;
RELATE role:editor->has_permission->permission:admin_library;
RELATE role:editor->has_permission->permission:admin_authors;
RELATE role:editor->has_permission->permission:admin_ai;
RELATE role:editor->has_permission->permission:admin_uploads;

-- Admin role inherits editor permissions plus future-only permissions.
RELATE role:admin->has_permission->permission:admin_jobs;
RELATE role:admin->has_permission->permission:admin_drafts;
RELATE role:admin->has_permission->permission:admin_publish;
RELATE role:admin->has_permission->permission:admin_library;
RELATE role:admin->has_permission->permission:admin_authors;
RELATE role:admin->has_permission->permission:admin_ai;
RELATE role:admin->has_permission->permission:admin_uploads;
