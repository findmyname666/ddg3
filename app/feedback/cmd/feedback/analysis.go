package main

import (
	"context"
	"log/slog"

	"github.com/findmyname666/ddg3/feedback/pkgs/analysis"
	"github.com/urfave/cli/v3"
)

func analysisCommand() *cli.Command {
	// Analysis-specific flags
	analysisFlags := []cli.Flag{
		&cli.StringFlag{
			Name:     "asana-token",
			Usage:    "Asana API token",
			Sources:  cli.EnvVars("ASANA_TOKEN"),
			Required: true,
		},
		&cli.StringFlag{
			Name:     "asana-workspace-gid",
			Usage:    "Asana workspace GID",
			Sources:  cli.EnvVars("ASANA_WORKSPACE_GID"),
			Required: true,
		},
		&cli.StringFlag{
			Name:     "asana-project-gid",
			Usage:    "Asana project GID",
			Sources:  cli.EnvVars("ASANA_PROJECT_GID"),
			Required: true,
		},
	}

	// Combine shared database flags with analysis-specific flags
	analysisFlags = append(dbFlags("feedback_analysis_app", "dev_analysis_password"), analysisFlags...)

	return &cli.Command{
		Name:   "analysis",
		Usage:  "Run the feedback analysis job",
		Flags:  analysisFlags,
		Action: runAnalysis,
	}
}

func runAnalysis(ctx context.Context, cmd *cli.Command) error {
	slog.Info("Starting feedback analysis job...")

	// Get database pool
	pool, err := getDBPool(ctx, cmd)
	if err != nil {
		return err
	}
	defer pool.Close()

	// Create aggregator
	aggregator := analysis.NewAggregator(analysis.Config{
		Pool:              pool,
		AsanaToken:        cmd.String("asana-token"),
		AsanaWorkspaceGID: cmd.String("asana-workspace-gid"),
		AsanaProjectGID:   cmd.String("asana-project-gid"),
	})

	slog.Info("Analysis job configuration",
		"db_user", cmd.String("db-user"),
		"asana_workspace", cmd.String("asana-workspace-gid"),
		"asana_project", cmd.String("asana-project-gid"))

	// Run aggregation
	if err := aggregator.Run(ctx); err != nil {
		return err
	}

	slog.Info("Analysis job completed successfully")

	return nil
}
