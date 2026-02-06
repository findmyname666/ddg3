// Package analysis provides feedback analysis and aggregation functionality.
package analysis

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/findmyname666/ddg3/feedback/pkgs/db"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Aggregator handles daily feedback aggregation
type Aggregator struct {
	pool           *pgxpool.Pool
	queries        *db.Queries
	asanaToken     string
	asanaWorkspace string
	asanaProject   string
}

// Config holds the configuration for the aggregator
type Config struct {
	Pool              *pgxpool.Pool
	AsanaToken        string
	AsanaWorkspaceGID string
	AsanaProjectGID   string
}

// NewAggregator creates a new aggregator instance
func NewAggregator(cfg Config) *Aggregator {
	return &Aggregator{
		pool:           cfg.Pool,
		queries:        db.New(cfg.Pool),
		asanaToken:     cfg.AsanaToken,
		asanaWorkspace: cfg.AsanaWorkspaceGID,
		asanaProject:   cfg.AsanaProjectGID,
	}
}

// Run executes the daily aggregation job
func (a *Aggregator) Run(ctx context.Context) error {
	slog.Info("Starting daily feedback aggregation...")

	// Check if report run already exists
	exists, err := a.dbReportExists(ctx)
	if err != nil {
		return fmt.Errorf("failed to check if report run exists: %w", err)
	}

	if exists {
		slog.Info("Report run already exists, skipping aggregation")

		return nil
	}

	// Calculate time window (last 24 hours in UTC)
	windowStart, windowEnd := calculateTimeWindow()

	// Query feedback counts
	counts, err := a.dbCountFeedback(ctx, windowStart, windowEnd)
	if err != nil {
		return fmt.Errorf("failed to query feedback counts: %w", err)
	}

	// Create Asana task
	asanaTaskGID, err := a.createAsanaTask(ctx, counts, windowStart, windowEnd)
	if err != nil {
		return fmt.Errorf("failed to create Asana task: %w", err)
	}

	// Create report run in database
	report, err := a.dbReportCreate(
		ctx,
		windowStart, windowEnd,
		counts.PositiveCount, counts.NegativeCount,
		asanaTaskGID,
	)
	if err != nil {
		return fmt.Errorf("failed to create report: %w", err)
	}

	slog.Info("Report created successfully",
		"report_date", report.ReportDate,
		"positive_count", report.PositiveCount,
		"negative_count", report.NegativeCount)

	return nil
}
