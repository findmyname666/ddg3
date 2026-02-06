package analysis

import (
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
)

func TestGetCurrentDate(t *testing.T) {
	result := getCurrentDate()
	now := time.Now().UTC()
	expected := now.Truncate(24 * time.Hour)

	tests := []struct {
		name      string
		checkFunc func(t *testing.T)
	}{
		{
			name: "should return UTC timezone",
			checkFunc: func(t *testing.T) {
				if result.Location() != time.UTC {
					t.Errorf("Expected UTC timezone, got %v", result.Location())
				}
			},
		},
		{
			name: "should be today's midnight",
			checkFunc: func(t *testing.T) {
				if !result.Equal(expected) {
					t.Errorf("Expected %v, got %v", expected, result)
				}
			},
		},
		{
			name: "should be at midnight (00:00:00.000)",
			checkFunc: func(t *testing.T) {
				if result.Hour() != 0 || result.Minute() != 0 || result.Second() != 0 || result.Nanosecond() != 0 {
					t.Errorf("Expected midnight (00:00:00.000), got %02d:%02d:%02d.%09d",
						result.Hour(), result.Minute(), result.Second(), result.Nanosecond())
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.checkFunc(t)
		})
	}
}

// TestGetCurrentDate_EdgeCases_WithMock demonstrates testing edge cases by mocking time
func TestGetCurrentDate_EdgeCases_WithMock(t *testing.T) {
	// Save original timeNow function
	originalTimeNow := timeNow
	defer func() {
		// Restore original after test
		timeNow = originalTimeNow
	}()

	tests := []struct {
		name         string
		mockTime     time.Time
		expectedDate time.Time
	}{
		{
			name:         "month boundary - March 1st",
			mockTime:     time.Date(2023, time.March, 1, 15, 30, 0, 0, time.UTC),
			expectedDate: time.Date(2023, time.March, 1, 0, 0, 0, 0, time.UTC),
		},
		{
			name:         "year boundary - Jan 1st",
			mockTime:     time.Date(2024, time.January, 1, 8, 45, 0, 0, time.UTC),
			expectedDate: time.Date(2024, time.January, 1, 0, 0, 0, 0, time.UTC),
		},
		{
			name:         "regular day - no boundary",
			mockTime:     time.Date(2024, time.June, 15, 12, 0, 0, 0, time.UTC),
			expectedDate: time.Date(2024, time.June, 15, 0, 0, 0, 0, time.UTC),
		},
		{
			name:         "end of month - Jan 31st",
			mockTime:     time.Date(2024, time.January, 31, 23, 59, 59, 0, time.UTC),
			expectedDate: time.Date(2024, time.January, 31, 0, 0, 0, 0, time.UTC),
		},
		{
			name:         "timezone handling - local time converted to UTC",
			mockTime:     time.Date(2024, time.March, 1, 2, 0, 0, 0, time.FixedZone("EST", -5*3600)),
			expectedDate: time.Date(2024, time.March, 1, 0, 0, 0, 0, time.UTC),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Mock time.Now() to return our test time
			timeNow = func() time.Time {
				return tt.mockTime
			}

			// Call the function
			result := getCurrentDate()

			// Verify the result
			if !result.Equal(tt.expectedDate) {
				t.Errorf("Expected %v, got %v", tt.expectedDate, result)
			}

			// Verify it's at midnight
			if result.Hour() != 0 || result.Minute() != 0 || result.Second() != 0 || result.Nanosecond() != 0 {
				t.Errorf("Expected midnight, got %02d:%02d:%02d.%09d",
					result.Hour(), result.Minute(), result.Second(), result.Nanosecond())
			}

			// Verify it's in UTC
			if result.Location() != time.UTC {
				t.Errorf("Expected UTC timezone, got %v", result.Location())
			}
		})
	}
}

func TestGetCurrentDate_DatabaseCompatibility(t *testing.T) {
	result := getCurrentDate()

	tests := []struct {
		name      string
		checkFunc func(t *testing.T)
	}{
		{
			name: "should be compatible with pgtype.Date",
			checkFunc: func(t *testing.T) {
				// This should compile and not panic
				pgDate := pgtype.Date{Time: result, Valid: true}
				if !pgDate.Valid {
					t.Error("pgtype.Date should be valid")
				}
				if !pgDate.Time.Equal(result) {
					t.Errorf("pgtype.Date.Time should equal result: expected %v, got %v", result, pgDate.Time)
				}
			},
		},
		{
			name: "should not be zero time",
			checkFunc: func(t *testing.T) {
				if result.IsZero() {
					t.Error("Result should not be zero time for database compatibility")
				}
			},
		},
		{
			name: "should have timezone information",
			checkFunc: func(t *testing.T) {
				if result.Location() == nil {
					t.Error("Result should have timezone information")
				}
			},
		},
		{
			name: "should be compatible with pgtype.Timestamptz",
			checkFunc: func(t *testing.T) {
				// Should also work with TIMESTAMP WITH TIME ZONE
				pgTimestamp := pgtype.Timestamptz{Time: result, Valid: true}
				if !pgTimestamp.Valid {
					t.Error("pgtype.Timestamptz should be valid")
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.checkFunc(t)
		})
	}
}

func TestCalculateTimeWindow(t *testing.T) {
	// Save original timeNow function
	originalTimeNow := timeNow
	defer func() {
		timeNow = originalTimeNow
	}()

	// Mock time to a specific moment
	mockTime := time.Date(2024, time.June, 15, 14, 30, 45, 123456789, time.UTC)
	timeNow = func() time.Time {
		return mockTime
	}

	// Call the function
	windowStart, windowEnd := calculateTimeWindow()

	// Expected values
	expectedEnd := time.Date(2024, time.June, 15, 0, 0, 0, 0, time.UTC)
	expectedStart := time.Date(2024, time.June, 14, 0, 0, 0, 0, time.UTC)

	tests := []struct {
		name      string
		checkFunc func(t *testing.T)
	}{
		{
			name: "windowEnd should be today's midnight UTC",
			checkFunc: func(t *testing.T) {
				if !windowEnd.Equal(expectedEnd) {
					t.Errorf("Expected windowEnd %v, got %v", expectedEnd, windowEnd)
				}
			},
		},
		{
			name: "windowStart should be yesterday's midnight UTC",
			checkFunc: func(t *testing.T) {
				if !windowStart.Equal(expectedStart) {
					t.Errorf("Expected windowStart %v, got %v", expectedStart, windowStart)
				}
			},
		},
		{
			name: "window should be exactly 24 hours",
			checkFunc: func(t *testing.T) {
				duration := windowEnd.Sub(windowStart)
				if duration != 24*time.Hour {
					t.Errorf("Expected 24 hour window, got %v", duration)
				}
			},
		},
		{
			name: "both times should be in UTC",
			checkFunc: func(t *testing.T) {
				if windowStart.Location() != time.UTC {
					t.Errorf("Expected windowStart in UTC, got %v", windowStart.Location())
				}
				if windowEnd.Location() != time.UTC {
					t.Errorf("Expected windowEnd in UTC, got %v", windowEnd.Location())
				}
			},
		},
		{
			name: "both times should be at midnight",
			checkFunc: func(t *testing.T) {
				if windowStart.Hour() != 0 ||
					windowStart.Minute() != 0 ||
					windowStart.Second() != 0 ||
					windowStart.Nanosecond() != 0 {
					t.Errorf(
						"Expected windowStart at midnight, got %02d:%02d:%02d.%09d",
						windowStart.Hour(),
						windowStart.Minute(),
						windowStart.Second(),
						windowStart.Nanosecond(),
					)
				}
				if windowEnd.Hour() != 0 ||
					windowEnd.Minute() != 0 ||
					windowEnd.Second() != 0 ||
					windowEnd.Nanosecond() != 0 {
					t.Errorf(
						"Expected windowEnd at midnight, got %02d:%02d:%02d.%09d",
						windowEnd.Hour(),
						windowEnd.Minute(),
						windowEnd.Second(),
						windowEnd.Nanosecond(),
					)
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.checkFunc(t)
		})
	}
}
