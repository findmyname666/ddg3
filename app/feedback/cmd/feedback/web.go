package main

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/findmyname666/ddg3/feedback/pkgs/web"
	"github.com/urfave/cli/v3"
)

// Maximum length of feedback message in characters. There is no hard limit in
// the database, but this is a sensible limit for a web application.
const MaxMessageLength = 10000

func webCommand() *cli.Command {
	// Web-specific flags
	webFlags := []cli.Flag{
		&cli.StringFlag{
			Name:    "host",
			Usage:   "Web server host",
			Value:   "127.0.0.1",
			Sources: cli.EnvVars("WEB_HOST"),
		},
		&cli.IntFlag{
			Name:    "port",
			Usage:   "Web server port",
			Value:   8080,
			Sources: cli.EnvVars("WEB_PORT"),
		},
		&cli.StringFlag{
			Name:    "static-path",
			Usage:   "Path to static files directory",
			Value:   "/app/static",
			Sources: cli.EnvVars("STATIC_PATH"),
		},
		&cli.IntFlag{
			Name:    "max-message-length",
			Usage:   "Maximum length of feedback message in characters",
			Value:   5000,
			Sources: cli.EnvVars("MAX_MESSAGE_LENGTH"),
		},
	}

	// Combine shared database flags with web-specific flags
	webFlags = append(dbFlags("web_app", "dev_web_password"), webFlags...)

	return &cli.Command{
		Name:   "web",
		Usage:  "Run the feedback web application",
		Flags:  webFlags,
		Action: runWeb,
	}
}

func runWeb(ctx context.Context, cmd *cli.Command) error {
	slog.Info("Starting web application...")

	// Validate max-message-length
	maxMessageLength := cmd.Int("max-message-length")
	if maxMessageLength < 1 || maxMessageLength > MaxMessageLength {
		return fmt.Errorf(
			"max-message-length must be between 1 and %d, got %d",
			MaxMessageLength, maxMessageLength,
		)
	}

	// Get database pool
	pool, err := getDBPool(ctx, cmd)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}
	defer pool.Close()

	// Create and start web server
	server, err := web.NewServer(web.Config{
		Host:             cmd.String("host"),
		Port:             cmd.Int("port"),
		Pool:             pool,
		StaticPath:       cmd.String("static-path"),
		MaxMessageLength: maxMessageLength,
	})
	if err != nil {
		return fmt.Errorf("failed to create web server: %w", err)
	}

	slog.Info("Web server configuration",
		"host", cmd.String("host"),
		"port", cmd.Int("port"),
		"static_path", cmd.String("static-path"),
		"max_message_length", cmd.Int("max-message-length"),
		"db_user", cmd.String("db-user"))

	return server.Start(ctx)
}
