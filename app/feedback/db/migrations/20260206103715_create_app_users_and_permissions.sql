-- migrate:up

-- Grant permissions to application users
-- Note: Users (web_app, feedback_analysis_app) are created by the Docker init script
-- Reason: Creating users requires CREATEROLE privilege, which migration_user doesn't have
-- This migration only grants table-specific permissions after tables are created

-- Revoke all default permissions
-- Purpose: Start with zero permissions (principle of least privilege)
-- Why: PostgreSQL may grant default permissions to PUBLIC role
-- Security: Ensures we explicitly grant only what's needed
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM web_app;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM feedback_analysis_app;

-- Web app permissions: RW on feedback table only

-- Grant DML operations on feedback table
-- SELECT: Read feedback records
-- INSERT: Create new feedback submissions
-- UPDATE: Modify existing feedback (if needed)
-- DELETE: Remove feedback (if needed)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE feedback TO web_app;

-- Grant sequence permissions for auto-increment ID
-- USAGE: Allows using sequences in the schema
-- SELECT: Allows reading current sequence values (e.g., currval, nextval)
-- Required for: INSERT operations on tables with GENERATED ALWAYS AS IDENTITY
-- Without this: INSERT will fail with "permission denied for sequence feedback_id_seq"
-- Security: Grant only the specific sequence for the feedback table
GRANT USAGE, SELECT ON SEQUENCE feedback_id_seq TO web_app;

-- Feedback analysis app permissions: RO on feedback, RW on report_runs

-- Grant read-only access to feedback table
-- SELECT: Read feedback records for aggregation
-- Why read-only: Analysis job should never modify user submissions
-- Security: Prevents accidental or malicious data corruption
GRANT SELECT ON TABLE feedback TO feedback_analysis_app;

-- Grant DML operations on report_runs table
-- SELECT: Read existing reports (check if report already exists for a date)
-- INSERT: Create new daily aggregation reports
-- UPDATE: Update report if needed (e.g., add Asana task GID after creation)
-- DELETE: Remove reports (if needed for cleanup or re-processing)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE report_runs TO feedback_analysis_app;

-- No sequence grant needed for feedback_analysis_app
-- Reason: Only has read-only access to feedback (no INSERT)
-- Reason: report_runs doesn't have auto-increment ID (no sequence)

-- migrate:down

-- Revoke all permissions
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM web_app;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM feedback_analysis_app;

-- Note: Users are not dropped here
-- Reason: User management is handled by the Docker init script
