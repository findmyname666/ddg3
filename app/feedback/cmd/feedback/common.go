package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"time"

	"github.com/findmyname666/ddg3/feedback/pkgs/db"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/urfave/cli/v3"
)

// dbFlags returns the common database connection flags
// defaultUser specifies the default value for the db-user flag
// defaultPassword specifies the default value for the db-password flag
func dbFlags(defaultUser, defaultPassword string) []cli.Flag {
	return []cli.Flag{
		&cli.StringFlag{
			Name:    "db-host",
			Usage:   "Database host",
			Value:   "localhost",
			Sources: cli.EnvVars("DB_HOST"),
		},
		&cli.IntFlag{
			Name:    "db-port",
			Usage:   "Database port",
			Value:   5432,
			Sources: cli.EnvVars("DB_PORT"),
		},
		&cli.StringFlag{
			Name:    "db-user",
			Usage:   "Database user",
			Value:   defaultUser,
			Sources: cli.EnvVars("DB_USER"),
		},
		&cli.StringFlag{
			Name:    "db-password",
			Usage:   "Database password",
			Value:   defaultPassword,
			Sources: cli.EnvVars("DB_PASSWORD"),
		},
		&cli.StringFlag{
			Name:    "db-database",
			Usage:   "Database name",
			Value:   "feedback",
			Sources: cli.EnvVars("DB_DATABASE"),
		},
		&cli.StringFlag{
			Name:    "db-sslmode",
			Usage:   "Database SSL mode (disable, require, verify-ca, verify-full)",
			Value:   "disable",
			Sources: cli.EnvVars("DB_SSLMODE"),
		},
		&cli.IntFlag{
			Name:    "db-max-conns",
			Usage:   "Maximum number of connections in the pool",
			Value:   25,
			Sources: cli.EnvVars("DB_MAX_CONNS"),
		},
		&cli.IntFlag{
			Name:    "db-min-conns",
			Usage:   "Minimum number of connections in the pool",
			Value:   5,
			Sources: cli.EnvVars("DB_MIN_CONNS"),
		},
		&cli.DurationFlag{
			Name:    "db-max-conn-lifetime",
			Usage:   "Maximum lifetime of a connection (e.g., 1h, 30m)",
			Value:   1 * time.Hour,
			Sources: cli.EnvVars("DB_MAX_CONN_LIFETIME"),
		},
		&cli.DurationFlag{
			Name:    "db-max-conn-idle-time",
			Usage:   "Maximum idle time of a connection (e.g., 30m, 15m)",
			Value:   30 * time.Minute,
			Sources: cli.EnvVars("DB_MAX_CONN_IDLE_TIME"),
		},
	}
}

// getDBPool creates a database connection pool from CLI flags
func getDBPool(ctx context.Context, cmd *cli.Command) (*pgxpool.Pool, error) {
	slog.Info("Connecting to database...",
		"host", cmd.String("db-host"),
		"port", cmd.Int("db-port"),
		"user", cmd.String("db-user"),
		"database", cmd.String("db-database"),
		"max_conns", cmd.Int("db-max-conns"),
		"min_conns", cmd.Int("db-min-conns"))

	pool, err := db.NewPool(ctx, db.Config{
		Host:            cmd.String("db-host"),
		Port:            cmd.Int("db-port"),
		User:            cmd.String("db-user"),
		Password:        cmd.String("db-password"),
		Database:        cmd.String("db-database"),
		SSLMode:         cmd.String("db-sslmode"),
		MaxConns:        int32(cmd.Int("db-max-conns")), // #nosec G115 - config values are reasonable
		MinConns:        int32(cmd.Int("db-min-conns")), // #nosec G115 - config values are reasonable
		MaxConnLifetime: cmd.Duration("db-max-conn-lifetime"),
		MaxConnIdleTime: cmd.Duration("db-max-conn-idle-time"),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create DB pool: %w", err)
	}

	slog.Info("Database connection pool established",
		"max_conns", cmd.Int("db-max-conns"),
		"min_conns", cmd.Int("db-min-conns"),
		"max_conn_lifetime", cmd.Duration("db-max-conn-lifetime"),
		"max_conn_idle_time", cmd.Duration("db-max-conn-idle-time"))
	return pool, nil
}

// setupLogging configures the global slog logger
func setupLogging(debug bool) {
	level := slog.LevelInfo

	if debug {
		level = slog.LevelDebug
	}

	handler := slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: level,
		// set timezone to utc
		ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
			if a.Key == slog.TimeKey {
				return slog.Attr{Key: "time", Value: slog.StringValue(time.Now().UTC().Format(time.RFC3339))}
			}
			return a
		},
	})

	logger := slog.New(handler)
	slog.SetDefault(logger)

	slog.Debug("Logging configured",
		"level", level.String())
}
