package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"database/sql"
	"encoding/base64"
	"errors"
	"fmt"
	"net/mail"
	"strings"
	"time"
	"unicode/utf8"

	"golang.org/x/crypto/argon2"
)

const sessionTTL = 24 * time.Hour

var (
	errUnauthorized = errors.New("invalid credentials or session")
	errInvalidUser  = errors.New("invalid email or password")
	errEmailTaken   = errors.New("email already registered")
)

type Service struct {
	db  *sql.DB
	now func() time.Time
}

type User struct {
	ID    int64  `json:"id"`
	Email string `json:"email"`
}

type session struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expires_at"`
}

func New(db *sql.DB) *Service {
	return &Service{db: db, now: time.Now}
}

func (s *Service) CreateUser(ctx context.Context, email, password string) (User, error) {
	return s.saveUser(ctx, email, password, false)
}

func (s *Service) SeedDemo(ctx context.Context) error {
	user, err := s.saveUser(ctx, "demo@example.com", "demo", true)
	if err != nil {
		return err
	}
	_, err = s.db.ExecContext(ctx, `
		INSERT INTO profiles (user_id, display_name, avatar_url)
		VALUES (?, 'Demo', 'https://github.com/fgp555.png')
		ON CONFLICT(user_id) DO NOTHING
	`, user.ID)
	return err
}

func (s *Service) saveUser(ctx context.Context, email, password string, replacePassword bool) (User, error) {
	email = normalizeEmail(email)
	address, err := mail.ParseAddress(email)
	if err != nil || address.Address != email || len(email) > 254 ||
		utf8.RuneCountInString(password) < 4 || len(password) > 1024 {
		return User{}, errInvalidUser
	}

	salt := make([]byte, 16)
	rand.Read(salt)
	user := User{Email: email}
	err = s.db.QueryRowContext(ctx, `
		INSERT INTO users (email, password_hash, password_salt) VALUES (?, ?, ?)
		ON CONFLICT(email) DO UPDATE SET
			password_hash = excluded.password_hash,
			password_salt = excluded.password_salt
		WHERE ?
		RETURNING id
	`, email, passwordHash(password, salt), salt, replacePassword).Scan(&user.ID)
	if errors.Is(err, sql.ErrNoRows) {
		return User{}, errEmailTaken
	}
	if err != nil {
		return User{}, fmt.Errorf("save user: %w", err)
	}
	return user, nil
}

func (s *Service) login(ctx context.Context, email, password string) (session, error) {
	var id int64
	// Use the same hashing work for an unknown email.
	hash, salt := make([]byte, 32), make([]byte, 16)
	err := s.db.QueryRowContext(ctx, `
		SELECT id, password_hash, password_salt FROM users WHERE email = ?
	`, normalizeEmail(email)).Scan(&id, &hash, &salt)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return session{}, err
	}
	if subtle.ConstantTimeCompare(passwordHash(password, salt), hash) != 1 || err != nil {
		return session{}, errUnauthorized
	}

	raw := make([]byte, 32)
	rand.Read(raw)
	token := base64.RawURLEncoding.EncodeToString(raw)
	digest := sha256.Sum256([]byte(token))
	expiresAt := s.now().UTC().Add(sessionTTL).Truncate(time.Second)
	_, err = s.db.ExecContext(ctx, `
		INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?, ?, ?)
	`, digest[:], id, expiresAt.Unix())
	if err != nil {
		return session{}, err
	}
	return session{Token: token, ExpiresAt: expiresAt}, nil
}

func (s *Service) logout(ctx context.Context, token string) error {
	digest := sha256.Sum256([]byte(token))
	result, err := s.db.ExecContext(ctx, `
		DELETE FROM sessions WHERE token_hash = ? AND expires_at > ?
	`, digest[:], s.now().Unix())
	if err != nil {
		return err
	}
	count, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if count == 0 {
		return errUnauthorized
	}
	return nil
}

func (s *Service) deleteAccount(ctx context.Context, token string) error {
	digest := sha256.Sum256([]byte(token))
	result, err := s.db.ExecContext(ctx, `
		DELETE FROM users WHERE id = (
			SELECT user_id FROM sessions WHERE token_hash = ? AND expires_at > ?
		)
	`, digest[:], s.now().Unix())
	if err != nil {
		return err
	}
	count, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if count == 0 {
		return errUnauthorized
	}
	return nil
}

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func passwordHash(password string, salt []byte) []byte {
	return argon2.IDKey([]byte(password), salt, 2, 19*1024, 1, 32)
}
