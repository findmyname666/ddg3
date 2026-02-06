package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/url"
	"path/filepath"

	"github.com/amacneil/dbmate/v2/pkg/dbmate"
	_ "github.com/amacneil/dbmate/v2/pkg/driver/postgres"
	"github.com/urfave/cli/v3"
)

var migrateCommandDescription = `Run database migrations using dbmate.

This command will:
  1. Connect to the database using migration_user credentials
  2. Create the database if it doesn't exist
  3. Run all pending migrations from app/feedback/db/migrations/
  4. Update the schema_migrations table

Examples:
  # Run migrations with default settings
  feedback migrate

  # Run migrations with custom database
  feedback migrate --db-host=prod-db.example.com --db-user=migration_user

  # Run migrations with environment variables
  export DB_HOST=prod-db.example.com
  export DB_USER=migration_user
  export DB_PASSWORD=secure_password
  feedback migrate

  # Specify custom migrations directory
  feedback migrate --migrations-dir=/path/to/migrations
`

func migrateCommand() *cli.Command {
	// Migration-specific flags
	migrateFlags := []cli.Flag{
		&cli.StringFlag{
			Name:    "migrations-dir",
			Usage:   "Path to migrations directory",
			Value:   "app/feedback/db/migrations",
			Sources: cli.EnvVars("MIGRATIONS_DIR"),
		},
		&cli.BoolFlag{
			Name:    "dump-schema",
			Usage:   "Auto-update/generate local schema file",
			Value:   false,
			Sources: cli.EnvVars("DUMP_SCHEMA"),
		},
	}

	// Combine shared database flags with migration-specific flags
	migrateFlags = append(dbFlags("migration_user", "dev_migration_password"), migrateFlags...)

	return &cli.Command{
		Name:        "migrate",
		Usage:       "Run database migrations",
		Description: migrateCommandDescription,
		Flags:       migrateFlags,
		Action:      runMigrate,
	}
}

func runMigrate(ctx context.Context, cmd *cli.Command) error {
	slog.Info("Starting database migration...")

	// Build database URL with properly encoded credentials
	// URL-encode username and password to handle special characters
	dbUser := url.QueryEscape(cmd.String("db-user"))
	dbPassword := url.QueryEscape(cmd.String("db-password"))

	urlStr := fmt.Sprintf("postgres://%s:%s@%s:%d/%s?sslmode=%s",
		dbUser,
		dbPassword,
		cmd.String("db-host"),
		cmd.Int("db-port"),
		cmd.String("db-database"),
		cmd.String("db-sslmode"),
	)

	dbURL, err := url.Parse(urlStr)
	if err != nil {
		return fmt.Errorf("failed to parse database URL: %w", err)
	}

	// Create dbmate instance
	db := dbmate.New(dbURL)

	// Get absolute path to migrations directory
	migrationsDir, err := filepath.Abs(cmd.String("migrations-dir"))
	if err != nil {
		return fmt.Errorf("failed to resolve migrations directory: %w", err)
	}

	db.MigrationsDir = []string{migrationsDir}

	// Configure options
	db.AutoDumpSchema = !cmd.Bool("dump-schema")
	db.Verbose = cmd.Bool("verbose")

	slog.Info("Running migrations...", "directory", migrationsDir)

	// Create database and run migrations
	if err := db.CreateAndMigrate(); err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	slog.Info("Database migration completed successfully")

	return nil
}
