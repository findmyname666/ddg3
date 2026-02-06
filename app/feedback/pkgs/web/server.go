// Package web provides HTTP server functionality for the feedback web application.
package web

import (
	"context"
	"fmt"
	"io/fs"
	"log/slog"
	"net/http"
	"path/filepath"
	"strings"
	"time"

	"github.com/findmyname666/ddg3/feedback/pkgs/db"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Server represents the HTTP server for the web application
type Server struct {
	host             string
	port             int
	pool             *pgxpool.Pool
	queries          *db.Queries
	server           *http.Server
	staticPath       string
	maxMessageLength int
}

// Config holds the configuration for the web server
type Config struct {
	Host             string
	Port             int
	Pool             *pgxpool.Pool
	StaticPath       string
	MaxMessageLength int
}

// secureFileSystem wraps http.Dir to prevent directory traversal and hidden file access
type secureFileSystem struct {
	fs http.FileSystem
}

// Open implements http.FileSystem with security checks
func (sfs secureFileSystem) Open(name string) (http.File, error) {
	// Clean the path to prevent directory traversal
	name = filepath.Clean(name)

	// Prevent access to hidden files/directories (starting with .)
	if containsHiddenPath(name) {
		return nil, fs.ErrNotExist
	}

	// Prevent directory traversal outside the root
	if strings.Contains(name, "..") {
		return nil, fs.ErrPermission
	}

	return sfs.fs.Open(name)
}

// containsHiddenPath checks if any path component starts with a dot
func containsHiddenPath(path string) bool {
	parts := strings.Split(filepath.ToSlash(path), "/")
	for _, part := range parts {
		if strings.HasPrefix(part, ".") && part != "." {
			return true
		}
	}

	return false
}

// NewServer creates a new web server instance
func NewServer(cfg Config) (*Server, error) {
	// Load templates once during server initialization
	if err := initTemplates(); err != nil {
		return nil, fmt.Errorf("failed to initialize templates: %w", err)
	}

	return &Server{
		host:             cfg.Host,
		port:             cfg.Port,
		pool:             cfg.Pool,
		queries:          db.New(cfg.Pool),
		staticPath:       cfg.StaticPath,
		maxMessageLength: cfg.MaxMessageLength,
	}, nil
}

// Start starts the HTTP server
func (s *Server) Start(ctx context.Context) error {
	mux := http.NewServeMux()

	// Static files with security wrapper
	slog.Info("Serving static files", "path", s.staticPath)
	secureFS := secureFileSystem{fs: http.Dir(s.staticPath)}
	fileServer := http.FileServer(secureFS)

	// Handle static files
	mux.Handle("/static/", http.StripPrefix("/static/", fileServer))

	// Handle routes
	mux.HandleFunc("/", s.handleFeedbackForm)
	mux.HandleFunc("/submit", s.handleFeedbackSubmit)
	mux.HandleFunc("/thanks", s.handleThanks)

	// Handle health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		if _, err := fmt.Fprintf(w, "OK\n"); err != nil {
			slog.Warn("Failed to write health check response", "error", err)
		}
	})

	s.server = &http.Server{
		Addr:         fmt.Sprintf("%s:%d", s.host, s.port),
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	slog.Info("Starting HTTP server", "addr", s.server.Addr)

	// Start server in a goroutine
	errChan := make(chan error, 1)
	go func() {
		if err := s.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			errChan <- err
		}
	}()

	// Wait for context cancellation or server error
	select {
	case <-ctx.Done():
		return s.Shutdown(context.Background())
	case err := <-errChan:
		return err
	}
}

// Shutdown gracefully shuts down the server
func (s *Server) Shutdown(ctx context.Context) error {
	slog.Info("Shutting down HTTP server...")

	shutdownCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	if err := s.server.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("server shutdown failed: %w", err)
	}

	slog.Info("HTTP server stopped")

	return nil
}
