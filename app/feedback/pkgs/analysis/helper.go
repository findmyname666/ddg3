package analysis

import "time"

// timeNow is a variable that can be overridden in tests
// In production, it uses time.Now
var timeNow = time.Now

// getCurrentDate returns the current date at midnight UTC
// This is useful for testing and ensures consistent date calculation across the codebase
func getCurrentDate() time.Time {
	return timeNow().UTC().Truncate(24 * time.Hour)
}

// calculateTimeWindow calculates a 24-hour time window ending at today's midnight UTC
// Returns windowStart and windowEnd times for querying feedback data
func calculateTimeWindow() (windowStart, windowEnd time.Time) {
	now := timeNow().UTC()
	windowEnd = now.Truncate(24 * time.Hour)
	windowStart = windowEnd.Add(-24 * time.Hour)

	return windowStart, windowEnd
}
