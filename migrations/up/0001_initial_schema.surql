-- Users table: authentication and authorization only
DEFINE TABLE IF NOT EXISTS user SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS username      ON user TYPE string;
DEFINE FIELD IF NOT EXISTS email         ON user TYPE string ASSERT string::is_email($value);
DEFINE FIELD IF NOT EXISTS password_hash ON user TYPE string;
DEFINE FIELD IF NOT EXISTS is_active     ON user TYPE bool DEFAULT true;
DEFINE FIELD IF NOT EXISTS is_verified   ON user TYPE bool DEFAULT false;
DEFINE FIELD IF NOT EXISTS created_at    ON user TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at    ON user TYPE datetime DEFAULT time::now() VALUE time::now();
DEFINE FIELD IF NOT EXISTS last_login    ON user TYPE option<datetime>;
DEFINE FIELD IF NOT EXISTS metadata      ON user TYPE object DEFAULT {};

DEFINE INDEX IF NOT EXISTS user_username_idx ON user COLUMNS username UNIQUE;
DEFINE INDEX IF NOT EXISTS user_email_idx    ON user COLUMNS email    UNIQUE;

-- Profiles table: expandable user profile information
DEFINE TABLE IF NOT EXISTS profile SCHEMAFULL;

DEFINE FIELD IF NOT EXISTS user         ON profile TYPE record<user>;
DEFINE FIELD IF NOT EXISTS first_name   ON profile TYPE option<string>;
DEFINE FIELD IF NOT EXISTS last_name    ON profile TYPE option<string>;
DEFINE FIELD IF NOT EXISTS display_name ON profile TYPE option<string>;
DEFINE FIELD IF NOT EXISTS avatar_url   ON profile TYPE option<string>;
DEFINE FIELD IF NOT EXISTS bio          ON profile TYPE option<string>;
DEFINE FIELD IF NOT EXISTS language     ON profile TYPE string DEFAULT "en";
DEFINE FIELD IF NOT EXISTS country      ON profile TYPE string DEFAULT "US";
DEFINE FIELD IF NOT EXISTS timezone     ON profile TYPE option<string>;
DEFINE FIELD IF NOT EXISTS phone        ON profile TYPE option<string>;
DEFINE FIELD IF NOT EXISTS website      ON profile TYPE option<string>;
DEFINE FIELD IF NOT EXISTS created_at   ON profile TYPE datetime DEFAULT time::now() READONLY;
DEFINE FIELD IF NOT EXISTS updated_at   ON profile TYPE datetime DEFAULT time::now() VALUE time::now();

DEFINE INDEX IF NOT EXISTS profile_user_idx ON profile COLUMNS user UNIQUE;
