-- name: CreateReportRun :one
INSERT INTO report_runs (
    report_date,
    window_start,
    window_end,
    positive_count,
    negative_count,
    asana_task_gid
) VALUES (
    $1, $2, $3, $4, $5, $6
) RETURNING *;

-- name: GetReportRun :one
SELECT * FROM report_runs
WHERE report_date = $1;

-- name: ListReportRuns :many
-- Retrieves a paginated list of report runs, ordered by most recent first.
-- Used for displaying historical analysis reports with pagination support.
-- Parameters: $1 = limit (number of records), $2 = offset (for pagination)
SELECT * FROM report_runs
ORDER BY report_date DESC
LIMIT $1 OFFSET $2;

-- name: UpdateAsanaTaskGid :exec
UPDATE report_runs
SET asana_task_gid = $2
WHERE report_date = $1;

-- name: ReportRunExists :one
-- Checks if a report run already exists for a specific date.
-- Returns true if a report exists, false otherwise.
-- Used to prevent duplicate report generation (idempotency check).
-- Parameter: $1 = report_date (DATE)
SELECT EXISTS(
    SELECT 1 FROM report_runs
    WHERE report_date = $1
);

-- name: GetLatestReportRun :one
SELECT * FROM report_runs
ORDER BY report_date DESC
LIMIT 1;
