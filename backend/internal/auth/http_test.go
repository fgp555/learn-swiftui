package auth

import (
	"bytes"
	"encoding/json"
	"image"
	"image/jpeg"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/fgp555/learn-swiftui/backend/internal/sqlite"
	"github.com/gin-gonic/gin"
)

func TestSessionFlow(t *testing.T) {
	dbPath := filepath.Join(t.TempDir(), "test.sqlite")
	db, err := sqlite.Open(t.Context(), dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	service := New(db)
	now := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	service.now = func() time.Time { return now }

	const email = "demo@example.com"
	const password = "a local test password"
	if _, err := service.CreateUser(t.Context(), email, password); err != nil {
		t.Fatal(err)
	}
	router := gin.New()
	service.RegisterRoutes(router.Group("/v1/auth"))

	request := func(method, path, body, token string, status int) *httptest.ResponseRecorder {
		t.Helper()
		r := httptest.NewRequest(method, "/v1/auth/"+path, strings.NewReader(body))
		if token != "" {
			r.Header.Set("Authorization", "Bearer "+token)
		}
		w := httptest.NewRecorder()
		router.ServeHTTP(w, r)
		if w.Code != status {
			t.Fatalf("%s %s: got %d, want %d, body %s", method, path, w.Code, status, w.Body)
		}
		return w
	}
	login := func(email, password string, status int) *httptest.ResponseRecorder {
		t.Helper()
		body, err := json.Marshal(map[string]string{"email": email, "password": password})
		if err != nil {
			t.Fatal(err)
		}
		return request(http.MethodPost, "login", string(body), "", status)
	}
	readSession := func(w *httptest.ResponseRecorder) session {
		t.Helper()
		var result session
		if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
			t.Fatal(err)
		}
		if result.Token == "" || !result.ExpiresAt.Equal(now.Add(sessionTTL)) {
			t.Fatal("expected a token and the configured expiry")
		}
		return result
	}

	request(http.MethodPost, "login", `{"email":`, "", http.StatusBadRequest)
	wrongPassword := login(email, "wrong password", http.StatusUnauthorized)
	unknownEmail := login("unknown@example.com", password, http.StatusUnauthorized)
	if wrongPassword.Body.String() != unknownEmail.Body.String() {
		t.Fatal("invalid login responses should match")
	}

	active := readSession(login(" DEMO@example.com ", password, http.StatusOK))
	request(http.MethodGet, "me", "", "", http.StatusUnauthorized)
	profileResponse := request(http.MethodGet, "me", "", active.Token, http.StatusOK)
	var user User
	if err := json.Unmarshal(profileResponse.Body.Bytes(), &user); err != nil || user.Email != email || user.ID == 0 {
		t.Fatalf("unexpected profile: %s", profileResponse.Body)
	}

	request(http.MethodPost, "logout", "", active.Token, http.StatusNoContent)
	request(http.MethodGet, "me", "", active.Token, http.StatusUnauthorized)

	active = readSession(login(email, password, http.StatusOK))
	now = active.ExpiresAt
	request(http.MethodGet, "me", "", active.Token, http.StatusUnauthorized)

	if err := service.SeedDemo(t.Context()); err != nil {
		t.Fatal(err)
	}
	demo := readSession(login(email, "demo", http.StatusOK))
	request(http.MethodGet, "me", "", demo.Token, http.StatusOK)

	readProfile := func(w *httptest.ResponseRecorder) userProfile {
		t.Helper()
		var profile userProfile
		if err := json.Unmarshal(w.Body.Bytes(), &profile); err != nil {
			t.Fatal(err)
		}
		return profile
	}
	profile := readProfile(request(http.MethodGet, "me", "", demo.Token, http.StatusOK))
	if profile.DisplayName != "Demo" || profile.AvatarURL == nil ||
		*profile.AvatarURL != "https://github.com/fgp555.png" || profile.HasUploadedAvatar {
		t.Fatalf("unexpected demo profile: %+v", profile)
	}
	request(http.MethodPatch, "me", `{"display_name":"Taylor"}`, "", http.StatusUnauthorized)
	profile = readProfile(request(http.MethodPatch, "me", `{"display_name":" Taylor "}`, demo.Token, http.StatusOK))
	if profile.DisplayName != "Taylor" || profile.AvatarURL == nil {
		t.Fatalf("name-only edits should keep the avatar: %+v", profile)
	}

	request(http.MethodPatch, "me", `{"display_name":"Taylor","avatar_jpeg":"YWJj"}`, demo.Token, http.StatusBadRequest)
	var jpegData bytes.Buffer
	if err := jpeg.Encode(&jpegData, image.NewRGBA(image.Rect(0, 0, 1, 1)), nil); err != nil {
		t.Fatal(err)
	}
	body, err := json.Marshal(profileUpdate{DisplayName: "Taylor", AvatarJPEG: jpegData.Bytes()})
	if err != nil {
		t.Fatal(err)
	}
	profile = readProfile(request(http.MethodPatch, "me", string(body), demo.Token, http.StatusOK))
	if profile.ID == 0 || profile.Email != email || profile.AvatarURL != nil || !profile.HasUploadedAvatar {
		t.Fatalf("unexpected uploaded profile: %+v", profile)
	}
	request(http.MethodGet, "me/avatar", "", "", http.StatusUnauthorized)
	avatar := request(http.MethodGet, "me/avatar", "", demo.Token, http.StatusOK)
	if !bytes.Equal(avatar.Body.Bytes(), jpegData.Bytes()) || avatar.Header().Get("Content-Type") != "image/jpeg" {
		t.Fatal("unexpected avatar response")
	}

	request(http.MethodPatch, "me", `{"display_name":"Taylor","remove_avatar":true}`, demo.Token, http.StatusOK)
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}
	reopened, err := sqlite.Open(t.Context(), dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer reopened.Close()
	service.db = reopened
	if err := service.SeedDemo(t.Context()); err != nil {
		t.Fatal(err)
	}
	profile = readProfile(request(http.MethodGet, "me", "", demo.Token, http.StatusOK))
	if profile.DisplayName != "Taylor" || profile.AvatarURL != nil || profile.HasUploadedAvatar {
		t.Fatalf("demo seed overwrote profile edits: %+v", profile)
	}
	request(http.MethodGet, "me/avatar", "", demo.Token, http.StatusNotFound)

	const newEmail = "swift@example.com"
	const registration = `{"email":"swift@example.com","password":"1234"}`
	request(http.MethodPost, "register", `{"email":"swift@example.com","password":"123"}`, "", http.StatusBadRequest)
	request(http.MethodPost, "register", registration, "", http.StatusCreated)
	request(http.MethodPost, "register", registration, "", http.StatusConflict)
	first := readSession(login(newEmail, "1234", http.StatusOK))
	second := readSession(login(newEmail, "1234", http.StatusOK))
	request(http.MethodDelete, "me", "", "", http.StatusUnauthorized)
	request(http.MethodDelete, "me", "", first.Token, http.StatusNoContent)
	login(newEmail, "1234", http.StatusUnauthorized)
	request(http.MethodPost, "register", registration, "", http.StatusCreated)
	request(http.MethodGet, "me", "", first.Token, http.StatusUnauthorized)
	request(http.MethodGet, "me", "", second.Token, http.StatusUnauthorized)
	request(http.MethodGet, "me", "", demo.Token, http.StatusOK)

}
