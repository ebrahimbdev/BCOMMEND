-- Legacy plaintext notes remain untouched and are not exposed by the encrypted API.
CREATE TABLE encrypted_notes (
  id TEXT PRIMARY KEY NOT NULL,
  owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  envelope TEXT NOT NULL,
  version INTEGER NOT NULL CHECK(version >= 1),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
) STRICT;
CREATE INDEX encrypted_notes_owner_active_id ON encrypted_notes(owner_id, deleted_at, id);
