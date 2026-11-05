package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/fgp555/learn-swiftui/backend/internal/auth"
	"github.com/fgp555/learn-swiftui/backend/internal/sqlite"
	"github.com/gin-gonic/gin"
)

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func run(args []string) error {
	if len(args) != 0 && (len(args) != 2 || args[0] != "create-user") {
		return errors.New("usage: api [create-user EMAIL]")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	path := "data/myapp.sqlite"
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	db, err := sqlite.Open(ctx, path)
	if err != nil {
		return err
	}
	defer db.Close()

	service := auth.New(db)
	if len(args) == 2 {
		if _, err := service.CreateUser(ctx, args[1], os.Getenv("MYAPP_PASSWORD")); err != nil {
			return err
		}
		fmt.Println("User created")
		return nil
	}

	if err := service.SeedDemo(ctx); err != nil {
		return fmt.Errorf("seed demo user: %w", err)
	}

	router := gin.Default()
	router.RedirectTrailingSlash = false
	router.HandleMethodNotAllowed = true
	if err := router.SetTrustedProxies(nil); err != nil {
		return err
	}
	service.RegisterRoutes(router.Group("/v1/auth"))
	server := &http.Server{
		Addr:              "127.0.0.1:8080",
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       time.Minute,
	}
	log.Printf("Listening on http://%s", server.Addr)
	return server.ListenAndServe()
}
