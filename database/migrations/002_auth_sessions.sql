ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
CREATE UNIQUE INDEX IF NOT EXISTS users_email_normalized ON users(lower(email));
CREATE TABLE IF NOT EXISTS auth_sessions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id),
 expires_at timestamptz NOT NULL, revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS auth_tokens (
 hash text PRIMARY KEY, session_id uuid NOT NULL REFERENCES auth_sessions(id),
 kind text NOT NULL CHECK(kind IN ('access','refresh')), expires_at timestamptz NOT NULL,
 consumed_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS auth_tokens_session ON auth_tokens(session_id);
