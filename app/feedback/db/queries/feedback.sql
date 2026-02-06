-- name: CreateFeedback :one
INSERT INTO feedback (
    sentiment,
    message
) VALUES (
    $1, $2
) RETURNING *;

-- name: GetFeedback :one
SELECT * FROM feedback
WHERE id = $1;

-- name: ListFeedback :many
SELECT * FROM feedback
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: CountFeedbackBySentiment :one
SELECT
    COUNT(*) FILTER (WHERE sentiment = 'positive') AS positive_count,
    COUNT(*) FILTER (WHERE sentiment = 'negative') AS negative_count
FROM feedback
WHERE created_at >= $1 AND created_at < $2;

-- name: GetFeedbackInTimeRange :many
SELECT * FROM feedback
WHERE created_at >= $1 AND created_at < $2
ORDER BY created_at DESC;

-- name: DeleteOldFeedback :exec
DELETE FROM feedback
WHERE created_at < $1;
