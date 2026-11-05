package auth

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func (s *Service) RegisterRoutes(routes *gin.RouterGroup) {
	routes.POST("/register", s.handleRegister)
	routes.POST("/login", s.handleLogin)
	routes.GET("/me", s.handleMe)
	routes.HEAD("/me", s.handleMe)
	routes.DELETE("/me", s.handleDeleteAccount)
	routes.POST("/logout", s.handleLogout)
}

type credentials struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func decodeCredentials(c *gin.Context) (credentials, bool) {
	var input credentials
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, 8*1024)
	decoder := json.NewDecoder(c.Request.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil || decoder.Decode(new(any)) != io.EOF ||
		normalizeEmail(input.Email) == "" || len(input.Email) > 254 ||
		len(input.Password) == 0 || len(input.Password) > 1024 {
		writeError(c, http.StatusBadRequest, "invalid_request")
		return credentials{}, false
	}
	return input, true
}

func (s *Service) handleRegister(c *gin.Context) {
	input, ok := decodeCredentials(c)
	if !ok {
		return
	}
	user, err := s.CreateUser(c.Request.Context(), input.Email, input.Password)
	switch {
	case errors.Is(err, errInvalidUser):
		writeError(c, http.StatusBadRequest, "invalid_request")
	case errors.Is(err, errEmailTaken):
		writeError(c, http.StatusConflict, "email_taken")
	case err != nil:
		handleError(c, err)
	default:
		writeJSON(c, http.StatusCreated, user)
	}
}

func (s *Service) handleLogin(c *gin.Context) {
	input, ok := decodeCredentials(c)
	if !ok {
		return
	}
	session, err := s.login(c.Request.Context(), input.Email, input.Password)
	if err != nil {
		handleError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, session)
}

func (s *Service) handleMe(c *gin.Context) {
	token, err := bearerToken(c)
	if err != nil {
		handleError(c, err)
		return
	}
	user, err := s.currentUser(c.Request.Context(), token)
	if err != nil {
		handleError(c, err)
		return
	}
	writeJSON(c, http.StatusOK, user)
}

func (s *Service) handleLogout(c *gin.Context) {
	token, err := bearerToken(c)
	if err == nil {
		err = s.logout(c.Request.Context(), token)
	}
	if err != nil {
		handleError(c, err)
		return
	}
	c.Header("Cache-Control", "no-store")
	c.Status(http.StatusNoContent)
}

func (s *Service) handleDeleteAccount(c *gin.Context) {
	token, err := bearerToken(c)
	if err == nil {
		err = s.deleteAccount(c.Request.Context(), token)
	}
	if err != nil {
		handleError(c, err)
		return
	}
	c.Header("Cache-Control", "no-store")
	c.Status(http.StatusNoContent)
}

func bearerToken(c *gin.Context) (string, error) {
	parts := strings.Fields(c.GetHeader("Authorization"))
	if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || len(parts[1]) != 43 {
		return "", errUnauthorized
	}
	if _, err := base64.RawURLEncoding.Strict().DecodeString(parts[1]); err != nil {
		return "", errUnauthorized
	}
	return parts[1], nil
}

func handleError(c *gin.Context, err error) {
	if errors.Is(err, errUnauthorized) {
		if c.FullPath() == "/v1/auth/login" {
			writeError(c, http.StatusUnauthorized, "invalid_credentials")
			return
		}
		c.Header("WWW-Authenticate", "Bearer")
		writeError(c, http.StatusUnauthorized, "invalid_session")
		return
	}
	slog.ErrorContext(c.Request.Context(), "authentication request failed", "error", err)
	writeError(c, http.StatusInternalServerError, "internal_error")
}

func writeError(c *gin.Context, status int, code string) {
	writeJSON(c, status, map[string]string{"error": code})
}

func writeJSON(c *gin.Context, status int, body any) {
	c.Header("Cache-Control", "no-store")
	c.JSON(status, body)
}
