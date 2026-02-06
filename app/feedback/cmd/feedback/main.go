package main

import (
	"context"
	"log/slog"
	"os"

	"github.com/urfave/cli/v3"
)

func main() {
	cmd := &cli.Command{
		Name:  "feedback",
		Usage: "DuckDuckGo feedback application",
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name:    "debug",
				Usage:   "Enable debug log level",
				Value:   false,
				Sources: cli.EnvVars("DEBUG"),
			},
		},
		Before: func(ctx context.Context, cmd *cli.Command) (context.Context, error) {
			setupLogging(cmd.Bool("debug"))
			return ctx, nil
		},
		Commands: []*cli.Command{
			webCommand(),
			analysisCommand(),
			migrateCommand(),
		},
	}

	if err := cmd.Run(context.Background(), os.Args); err != nil {
		slog.Error("an irrecoverable error occurred", "err", err)
		os.Exit(1)
	}
}
