package web

import (
	"context"
	"log/slog"

	"github.com/findmyname666/ddg3/feedback/pkgs/db"
	"github.com/jackc/pgx/v5/pgtype"
)

// dbSaveFeedback saves feedback to the database
func (s *Server) dbSaveFeedback(ctx context.Context, sentiment, message string) (*db.Feedback, error) {
	slog.Debug("Saving feedback to database")

	// Convert sentiment to enum type
	dbSentimentType := db.SentimentTypePositive
	if sentiment == "negative" {
		dbSentimentType = db.SentimentTypeNegative
	}

	// Save to database
	var dbMessage pgtype.Text
	if message != "" {
		dbMessage = pgtype.Text{String: message, Valid: true}
	}

	feedback, err := s.queries.CreateFeedback(ctx, db.CreateFeedbackParams{
		Sentiment: dbSentimentType,
		Message:   dbMessage,
	})

	return &feedback, err
}
