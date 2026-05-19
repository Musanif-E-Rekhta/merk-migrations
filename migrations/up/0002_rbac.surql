-- =============================================================================
-- 0002_rbac
--   Graph-shaped RBAC:
--     user --(assigned_role)--> role --(has_permission)--> permission
--
--   Schema only. The actual role catalog (admin, editor, user) and
--   permission catalog (manage_users, admin:jobs, …) is bootstrapped
--   by `merk-seed::bootstrap_reference` so production deployments can
--   evolve the catalog without rewriting migrations.
-- =============================================================================

DEFINE TABLE OVERWRITE role SCHEMAFULL;
DEFINE FIELD OVERWRITE name ON role TYPE string;
DEFINE INDEX OVERWRITE role_name_idx ON role COLUMNS name UNIQUE;

DEFINE TABLE OVERWRITE permission SCHEMAFULL;
DEFINE FIELD OVERWRITE name ON permission TYPE string;
DEFINE INDEX OVERWRITE permission_name_idx ON permission COLUMNS name UNIQUE;

-- Graph edges. SCHEMALESS so future versions can attach optional
-- metadata (e.g. `granted_at`, `granted_by`) without a schema change.
-- UNIQUE on (in, out) makes both edges idempotent — repeated RELATEs
-- from the seed bootstrap are no-ops instead of duplicate edges.
DEFINE TABLE OVERWRITE assigned_role  TYPE RELATION IN user OUT role;
DEFINE TABLE OVERWRITE has_permission TYPE RELATION IN role OUT permission;

DEFINE INDEX OVERWRITE assigned_role_unique_idx  ON assigned_role  COLUMNS in, out UNIQUE;
DEFINE INDEX OVERWRITE has_permission_unique_idx ON has_permission COLUMNS in, out UNIQUE;
