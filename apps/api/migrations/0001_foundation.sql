PRAGMA foreign_keys = ON;

CREATE TABLE users (
  id TEXT PRIMARY KEY NOT NULL,
  created_at INTEGER NOT NULL
) STRICT;

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY NOT NULL CHECK(length(token_hash) = 64),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL CHECK(expires_at > created_at),
  revoked_at INTEGER
) STRICT;
CREATE INDEX sessions_user ON sessions(user_id);

CREATE TABLE notes (
  id TEXT PRIMARY KEY NOT NULL,
  owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 200),
  content TEXT NOT NULL CHECK(length(content) <= 20000),
  version INTEGER NOT NULL CHECK(version >= 1),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
) STRICT;
CREATE INDEX notes_owner_active_id ON notes(owner_id, deleted_at, id);
