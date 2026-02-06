#!/bin/bash
# Docker initialization script for PostgreSQL
# This runs automatically when the postgres container starts for the first time
# Files in /docker-entrypoint-initdb.d/ are executed in alphabetical order
#
# This script creates all database users with appropriate permissions.
# The actual schema migrations (tables, indexes, etc.) are run by the dedicated 'migration' service.

set -e

echo "Initializing FeedDuck database..."

# Create all database users
# Note: User creation requires CREATEROLE privilege, so it must be done by postgres superuser
# The migration_user will handle schema changes (CREATE TABLE, etc.) but not user management
echo "Creating database users..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- ============================================================================
    -- 1. Create migration_user (for running schema migrations)
    -- ============================================================================
    CREATE USER $DB_USER_MIGRATION_NAME WITH PASSWORD '$DB_USER_MIGRATION_PASSWORD';

    -- Grant all privileges on database for DDL operations (CREATE TABLE, ALTER, DROP, etc.)
    GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $DB_USER_MIGRATION_NAME;

    -- Grant schema permissions
    GRANT ALL ON SCHEMA public TO migration_user;

    -- Grant permissions on all existing and future tables/sequences
    -- This allows migration_user to manage all database objects
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO migration_user;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO migration_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO migration_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO migration_user;

    -- ============================================================================
    -- 2. Create web_app user (for web application)
    -- ============================================================================
    CREATE USER $DB_USER_WEB_NAME WITH PASSWORD '$DB_USER_WEB_PASSWORD';

    -- Grant connection and schema usage
    GRANT CONNECT ON DATABASE $POSTGRES_DB TO web_app;
    GRANT USAGE ON SCHEMA public TO web_app;

    -- Note: Table-specific permissions will be granted by migrations after tables are created

    -- ============================================================================
    -- 3. Create feedback_analysis_app user (for analysis job)
    -- ============================================================================
    CREATE USER $DB_USER_ANALYSIS_NAME WITH PASSWORD '$DB_USER_ANALYSIS_PASSWORD';

    -- Grant connection and schema usage
    GRANT CONNECT ON DATABASE $POSTGRES_DB TO feedback_analysis_app;
    GRANT USAGE ON SCHEMA public TO feedback_analysis_app;

    -- Note: Table-specific permissions will be granted by migrations after tables are created
EOSQL

echo ""
echo " Database users created successfully:"
echo "  - migration_user (DDL permissions for schema migrations)"
echo "  - web_app (will get RW on feedback table)"
echo "  - feedback_analysis_app (will get RO on feedback, RW on report_runs)"
echo ""
echo "Next steps:"
echo "  1. The 'migration' container will run dbmate migrations"
echo "  2. Migrations will create: feedback, report_runs tables"
echo "  3. Migrations will grant table-specific permissions to app users"
echo ""
echo "    WARNING: Using development passwords!"
echo "    Change in production using environment variables."
echo ""
