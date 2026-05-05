-- Roles table schema
DEFINE TABLE IF NOT EXISTS role SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS name ON role TYPE string;
DEFINE INDEX IF NOT EXISTS role_name_idx ON role COLUMNS name UNIQUE;

-- Permissions table schema
DEFINE TABLE IF NOT EXISTS permission SCHEMAFULL;
DEFINE FIELD IF NOT EXISTS name ON permission TYPE string;
DEFINE INDEX IF NOT EXISTS permission_name_idx ON permission COLUMNS name UNIQUE;

-- Graph relationships
DEFINE TABLE IF NOT EXISTS assigned_role TYPE RELATION IN user OUT role;
DEFINE TABLE IF NOT EXISTS has_permission TYPE RELATION IN role OUT permission;

-- Add basic roles and permissions
CREATE role:admin CONTENT { name: "Administrator" };
CREATE role:user CONTENT { name: "Standard User" };

CREATE permission:manage_users CONTENT { name: "Manage Users" };
CREATE permission:read_content CONTENT { name: "Read Content" };
CREATE permission:write_content CONTENT { name: "Write Content" };

-- Assign permissions to roles
RELATE role:admin->has_permission->permission:manage_users;
RELATE role:admin->has_permission->permission:read_content;
RELATE role:admin->has_permission->permission:write_content;

RELATE role:user->has_permission->permission:read_content;
RELATE role:user->has_permission->permission:write_content;
