package sqlite

import (
	"context"
	"database/sql"
	"fmt"

	_ "modernc.org/sqlite"
)

func Open(ctx context.Context, path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, err
	}
	// Keep SQLite access serialized in this single-process service.
	db.SetMaxOpenConns(1)

	_, err = db.ExecContext(ctx, `
		CREATE TABLE IF NOT EXISTS users (
			id INTEGER PRIMARY KEY,
			email TEXT NOT NULL UNIQUE,
			password_hash BLOB NOT NULL,
			password_salt BLOB NOT NULL
		);
		CREATE TABLE IF NOT EXISTS sessions (
			token_hash BLOB PRIMARY KEY NOT NULL,
			user_id INTEGER NOT NULL REFERENCES users(id),
			expires_at INTEGER NOT NULL
		);
		CREATE TABLE IF NOT EXISTS profiles (
			user_id INTEGER PRIMARY KEY REFERENCES users(id),
			display_name TEXT NOT NULL,
			avatar_url TEXT,
			avatar_jpeg BLOB
		);
		CREATE TRIGGER IF NOT EXISTS delete_user_profile
		AFTER DELETE ON users BEGIN
			DELETE FROM profiles WHERE user_id = OLD.id;
		END;
		CREATE TRIGGER IF NOT EXISTS delete_user_sessions
		AFTER DELETE ON users BEGIN
			DELETE FROM sessions WHERE user_id = OLD.id;
		END;
	`)
	if err != nil {
		db.Close()
		return nil, fmt.Errorf("initialize schema: %w", err)
	}
	return db, nil
}
