-- migrate:up
CREATE TABLE IF NOT EXISTS report_runs (
    report_date DATE PRIMARY KEY,
    window_start TIMESTAMP WITH TIME ZONE NOT NULL,
    window_end TIMESTAMP WITH TIME ZONE NOT NULL,
    positive_count INTEGER NOT NULL DEFAULT 0,
    negative_count INTEGER NOT NULL DEFAULT 0,
    asana_task_gid TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT report_runs_positive_count_check CHECK (positive_count >= 0),
    CONSTRAINT report_runs_negative_count_check CHECK (negative_count >= 0),
    CONSTRAINT report_runs_window_check CHECK (window_end > window_start)
);

-- Create index for efficient lookups by creation time
CREATE INDEX IF NOT EXISTS idx_report_runs_created_at ON report_runs(created_at DESC);

-- migrate:down
DROP INDEX IF EXISTS idx_report_runs_created_at;
DROP TABLE IF EXISTS report_runs;
