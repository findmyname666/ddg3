-- migrate:up

-- Create sentiment enum type
CREATE TYPE sentiment_type AS ENUM ('positive', 'negative');

-- Create feedback table
CREATE TABLE IF NOT EXISTS feedback (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    sentiment sentiment_type NOT NULL,
    message TEXT
);

-- Create index for efficient time-based queries (last 24 hours aggregation)
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON feedback(created_at DESC);

-- Create index for sentiment filtering
CREATE INDEX IF NOT EXISTS idx_feedback_sentiment ON feedback(sentiment);

-- migrate:down
DROP INDEX IF EXISTS idx_feedback_sentiment;
DROP INDEX IF EXISTS idx_feedback_created_at;
DROP TABLE IF EXISTS feedback;
DROP TYPE IF EXISTS sentiment_type;
