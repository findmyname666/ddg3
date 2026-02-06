package analysis

import (
	"context"
	"fmt"
	"log/slog"
	"math"
	"time"

	"github.com/findmyname666/ddg3/feedback/pkgs/db"
	"github.com/jackc/pgx/v5/pgtype"
)

// dbReportExists checks if a report run already exists for current day
func (a *Aggregator) dbReportExists(ctx context.Context) (bool, error) {
	reportDate := getCurrentDate()

	slog.Debug("Checking if report run exists",
		"report_date", reportDate)

	return a.queries.ReportRunExists(ctx, pgtype.Date{Time: reportDate, Valid: true})
}

func (a *Aggregator) dbReportCreate(
	ctx context.Context,
	windowStart, windowEnd time.Time,
	positiveCount, negativeCount int64,
	asanaTaskGID string,
) (*db.ReportRun, error) {
	// Create report run in database
	reportDate := pgtype.Date{Time: windowEnd, Valid: true}

	// Validate if value fits into int32
	if positiveCount > math.MaxInt32 || positiveCount < math.MinInt32 {
		return nil, fmt.Errorf("positive count %d exceeds int32 range", positiveCount)
	}

	if negativeCount > math.MaxInt32 || negativeCount < math.MinInt32 {
		return nil, fmt.Errorf("negative count %d exceeds int32 range", negativeCount)
	}

	report, err := a.queries.CreateReportRun(ctx, db.CreateReportRunParams{
		ReportDate:    reportDate,
		WindowStart:   pgtype.Timestamptz{Time: windowStart, Valid: true},
		WindowEnd:     pgtype.Timestamptz{Time: windowEnd, Valid: true},
		PositiveCount: int32(positiveCount), // #nosec G115 - validated above
		NegativeCount: int32(negativeCount), // #nosec G115 - validated above
		AsanaTaskGid:  pgtype.Text{String: asanaTaskGID, Valid: true},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to insert report run into DB: %w", err)
	}

	return &report, nil
}

func (a *Aggregator) dbCountFeedback(
	ctx context.Context,
	windowStart, windowEnd time.Time,
) (*db.CountFeedbackBySentimentRow, error) {
	slog.Debug("Aggregating feedback",
		"window_start", windowStart,
		"window_end", windowEnd)

	// Query feedback counts by sentiment
	counts, err := a.queries.CountFeedbackBySentiment(ctx, db.CountFeedbackBySentimentParams{
		CreatedAt:   pgtype.Timestamptz{Time: windowStart, Valid: true},
		CreatedAt_2: pgtype.Timestamptz{Time: windowEnd, Valid: true},
	})
	if err != nil {
		return nil, fmt.Errorf("failed to query feedback count from DB: %w", err)
	}

	slog.Debug("Feedback counts from DB",
		"positive", counts.PositiveCount,
		"negative", counts.NegativeCount)

	return &counts, nil
}
