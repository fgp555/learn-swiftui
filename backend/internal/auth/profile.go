package auth

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"image/jpeg"
	"io"
	"net/http"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
)

const maxAvatarBytes = 1024 * 1024

type userProfile struct {
	User
	DisplayName       string  `json:"display_name"`
	AvatarURL         *string `json:"avatar_url"`
	HasUploadedAvatar bool    `json:"has_uploaded_avatar"`
}

type profileUpdate struct {
	DisplayName  string `json:"display_name"`
	AvatarJPEG   []byte `json:"avatar_jpeg"`
	RemoveAvatar bool   `json:"remove_avatar"`
}

func (s *Service) profile(ctx context.Context, token string) (userProfile, error) {
	digest := sha256.Sum256([]byte(token))
	row := s.db.QueryRowContext(ctx, `
		SELECT users.id, users.email, COALESCE(profiles.display_name, ''),
			profiles.avatar_url, profiles.avatar_jpeg IS NOT NULL
		FROM sessions JOIN users ON users.id = sessions.user_id
		LEFT JOIN profiles ON profiles.user_id = users.id
		WHERE sessions.token_hash = ? AND sessions.expires_at > ?
	`, digest[:], s.now().Unix())
	return scanProfile(row)
}

func (s *Service) updateProfile(ctx context.Context, token string, input profileUpdate) (userProfile, error) {
	digest := sha256.Sum256([]byte(token))
	replaceAvatar := input.RemoveAvatar || len(input.AvatarJPEG) > 0
	var avatar any
	if len(input.AvatarJPEG) > 0 {
		avatar = input.AvatarJPEG
	}
	row := s.db.QueryRowContext(ctx, `
		INSERT INTO profiles (user_id, display_name, avatar_jpeg)
		SELECT sessions.user_id, ?, ? FROM sessions JOIN users ON users.id = sessions.user_id
		WHERE token_hash = ? AND expires_at > ?
		ON CONFLICT(user_id) DO UPDATE SET
			display_name = excluded.display_name,
			avatar_url = CASE WHEN ? THEN NULL ELSE profiles.avatar_url END,
			avatar_jpeg = CASE WHEN ? THEN excluded.avatar_jpeg ELSE profiles.avatar_jpeg END
		RETURNING user_id, (SELECT email FROM users WHERE id = profiles.user_id),
			display_name, avatar_url, avatar_jpeg IS NOT NULL
	`, input.DisplayName, avatar, digest[:], s.now().Unix(), replaceAvatar, replaceAvatar)
	return scanProfile(row)
}

func scanProfile(row *sql.Row) (userProfile, error) {
	var profile userProfile
	err := row.Scan(&profile.ID, &profile.Email, &profile.DisplayName, &profile.AvatarURL, &profile.HasUploadedAvatar)
	if errors.Is(err, sql.ErrNoRows) {
		return userProfile{}, errUnauthorized
	}
	return profile, err
}

func (s *Service) handleUpdateProfile(c *gin.Context) {
	token, err := bearerToken(c)
	if err != nil {
		handleError(c, err)
		return
	}

	var input profileUpdate
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 1500*1024)
	decoder := json.NewDecoder(c.Request.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil || decoder.Decode(new(any)) != io.EOF {
		writeError(c, http.StatusBadRequest, "invalid_profile")
		return
	}
	input.DisplayName = strings.TrimSpace(input.DisplayName)
	if input.DisplayName == "" || utf8.RuneCountInString(input.DisplayName) > 60 ||
		(input.RemoveAvatar && input.AvatarJPEG != nil) ||
		(input.AvatarJPEG != nil && !validAvatar(input.AvatarJPEG)) {
		writeError(c, http.StatusBadRequest, "invalid_profile")
		return
	}

	profile, err := s.updateProfile(c.Request.Context(), token, input)
	if err != nil {
		handleError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, profile)
}

func validAvatar(data []byte) bool {
	if len(data) == 0 || len(data) > maxAvatarBytes {
		return false
	}
	config, err := jpeg.DecodeConfig(bytes.NewReader(data))
	if err != nil || config.Width > 1024 || config.Height > 1024 {
		return false
	}
	_, err = jpeg.Decode(bytes.NewReader(data))
	return err == nil
}

func (s *Service) handleAvatar(c *gin.Context) {
	token, err := bearerToken(c)
	if err != nil {
		handleError(c, err)
		return
	}
	digest := sha256.Sum256([]byte(token))
	var avatar []byte
	err = s.db.QueryRowContext(c.Request.Context(), `
		SELECT profiles.avatar_jpeg FROM sessions JOIN users ON users.id = sessions.user_id
		LEFT JOIN profiles ON profiles.user_id = sessions.user_id
		WHERE sessions.token_hash = ? AND sessions.expires_at > ?
	`, digest[:], s.now().Unix()).Scan(&avatar)
	switch {
	case errors.Is(err, sql.ErrNoRows):
		handleError(c, errUnauthorized)
	case err != nil:
		handleError(c, err)
	case len(avatar) == 0:
		writeError(c, http.StatusNotFound, "avatar_not_found")
	default:
		c.Header("Cache-Control", "no-store")
		c.Data(http.StatusOK, "image/jpeg", avatar)
	}
}
