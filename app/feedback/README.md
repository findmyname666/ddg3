# Feedback Application

A unified Go application for DuckDuckGo feedback management with multiple
commands:

- **web**: HTTP server for receiving and managing feedback
- **analysis**: Daily aggregation job for analyzing feedback and creating
  reports
- **migrate**: Database migration management using [dbmate][8]

## Commands

### Web

The `feedback web` command runs the HTTP server for receiving and managing
feedback submissions. The feedback is stored in the database and the analysis job
will pick it up and create a report.

### Features

**Responsive Design** - Works on mobile, tablet, and desktop
**No JavaScript Framework** - Pure HTML/CSS with minimal vanilla JS
**Server-Side Rendering** - Fast, SEO-friendly, accessible
**Privacy-Focused** - No tracking, anonymous feedback
**UI** - Gradient background, smooth animations

### Implementation Details

#### HTML Templates (`pkgs/web/templates/`)

There are two HTML templates:

- **feedback.html** - Main feedback form with:
  - Emoji-based sentiment selection (Positive / Negative)
  - Optional message textarea with character counter
  - Client-side validation
  - Privacy notice
- **thanks.html** - Thank you page with ASCII duck art

#### Input Validation

App supports the following:

- Input sanitization
- Configurable message length validation (default: 5000 chars, max: 10000
  chars)
- Sentiment enum validation
- Directory traversal prevention for static files
- Hidden file access prevention

#### Routes

The following routes are implemented:

- `GET /` - Feedback form
- `POST /submit` - Form submission
- `GET /thanks` - Thank you page
- `GET /health` - Health check
- `/static/*` - Static file serving (CSS, images)

#### HTTP Server Configuration

- ReadTimeout: 15s
- WriteTimeout: 15s
- IdleTimeout: 60s
- Concurrent request handling (built-in Go feature)
- Graceful shutdown with 10s timeout

### Analysis

The `feedback analysis` command runs the daily aggregation job for analyzing
feedback and creating reports.

Main features:

- Aggregates feedback sentiment counts for the last 24 hours (previous midnight
  to current midnight)
- Creates a new report in the `report_runs` table
- Creates an Asana task for the report
- Idempotent: skips if a report already exists for the current day
- Assana task isn't created if there is no feedback for the day

### Migrate

The `feedback migrate` command runs the database migrations using [dbmate][8].
Reffer to section [Database Migrations](#database-migrations) for more
information.

## Security Model

**Critical**: Security is enforced at the **database level**, not the
application level.

### Database Users

1. **migration_user** (used by `feedback migrate`)
   - Permissions: DDL operations (CREATE, ALTER, DROP)
   - Used only for schema migrations

2. **web_app** (used by `feedback web`)
   - Permissions: Read/Write on `feedback` table
   - No access to: `report_runs` table

3. **feedback_analysis_app** (used by `feedback analysis`)
   - Permissions: Read-only on `feedback` table, Read/Write on `report_runs`
     table

Even though all commands are in the same binary, PostgreSQL enforces
permissions based on the database user credentials provided at runtime.

## Database Migrations

Database schema is managed using [dbmate][8] with migration files located in
[db/migrations/][7].

### Migration Workflow

Migrations are executed using the `feedback migrate` command and dedicated
`migration_user` user. The command is using `dbmate` under the hood to execute
the migrations.

**Important:** Applications (web, analysis) should NEVER run migrations. They
use restricted database users without DDL permissions.

### Creating New Migrations

```bash
# Create a new migration file
dbmate new migration_name

# This creates: db/migrations/YYYYMMDDHHMMSS_migration_name.sql
```

Migration file structure:

```sql
-- migrate:up
CREATE TABLE example (
    id INT PRIMARY KEY
);

-- migrate:down
DROP TABLE example;
```

### Rollback

Examples:

```bash
# Rollback last migration
dbmate rollback

# Check migration status
dbmate status
```

## DB Queries

DB queries are generated from SQL files in [db/queries/][9] using
[sqlc][6]. The generated code is in [pkgs/db/][10].

```bash
# From project root -g enerate Go code from SQL queries
make sqlc
```

## Building

The application can be built using `go build` or `make go-build` for local
testing. The resulting binary is in `bin/feedback`.

```bash
# From project root
make go-build

# Or directly from app/feedback
cd app/feedback
go build -o ../../bin/feedback ./cmd/feedback
```

## Development

### Single Dockerfile, Multiple Deployments

The application uses a multi-stage [Dockerfile][1]. The same image is used for
all deployments.

### Docker Compose

See [docker-compose.dev.yml][2] for a complete development environment with:

- PostgreSQL database with initialization scripts
- Automatic migrations on startup
- Web application with hot reload
- Nginx reverse proxy

```bash
# Run following commands from project root
#
# Generate SSL certificates
make ssl-dev

# Start everything
docker compose --file docker-compose.dev.yml up --build

# View logs
docker compose --file docker-compose.dev.yml logs -f

# Run analysis job manually
docker compose --file docker-compose.dev.yml run --rm analysis

# Stop everything
docker compose --file docker-compose.dev.yml down -v
```

## Configuration

Application can be configured using command line flags or environment
variables. Environment variables take precedence over command line flags.

You can explore configuration options by running:

```bash
cd app/feedback/
go run ./cmd/feedback/ --help
go run ./cmd/feedback/ migrate --help
go run ./cmd/feedback/ web --help
go run ./cmd/feedback/ analysis --help
```

## Database Connection Pool Configuration

The feedback application supports advanced database connection pool
configuration for production use.

### Configuration Options

- `--db-max-conns` (default: 25) - Maximum number of connections in the pool
  - Environment Variable: `DB_MAX_CONNS`
  - Production Recommendation: 25-100 depending on your workload

- `--db-min-conns` (default: 5) - Minimum number of connections in the pool
  - Environment Variable: `DB_MIN_CONNS`
  - Production Recommendation: 5-10

- `--db-max-conn-lifetime` (default: 1h) - Maximum lifetime of a connection
  - Environment Variable: `DB_MAX_CONN_LIFETIME`
  - Format: Duration string (e.g., `1h`, `30m`, `2h30m`)
  - Production Recommendation: 1h - 4h

- `--db-max-conn-idle-time` (default: 30m) - Maximum idle time of a connection
  - Environment Variable: `DB_MAX_CONN_IDLE_TIME`
  - Format: Duration string (e.g., `30m`, `15m`, `1h`)
  - Production Recommendation: 15m - 30m

### Production Examples

High-Traffic Web Application:

```bash
feedback web \
  --db-max-conns=50 \
  --db-min-conns=10 \
  --db-max-conn-lifetime=2h \
  --db-max-conn-idle-time=15m
```

Low-Traffic Analysis Job:

```bash
feedback analysis \
  --db-max-conns=10 \
  --db-min-conns=2 \
  --db-max-conn-lifetime=1h \
  --db-max-conn-idle-time=30m
```

### Adjusting PostgreSQL max_connections

Make sure your PostgreSQL `max_connections` setting can accommodate all your
application instances.

Formula: `max_conns_per_instance = (postgres_max_connections - reserved) /
number_of_app_instances`

Example: If PostgreSQL has 100 max connections and you run 3 app instances:
`(100 - 10) / 3 = 30` per instance

```sql
-- Check current max_connections
SHOW max_connections;

-- Set max_connections (requires PostgreSQL restart)
ALTER SYSTEM SET max_connections = 200;
```

After changing `max_connections`, restart PostgreSQL for the change to take
effect.

### Troubleshooting

#### "Too many connections" error

- **Cause**: Total connections from all app instances exceed PostgreSQL's
  `max_connections`
- **Solutions**:
  - Reduce `--db-max-conns` per instance
  - Increase PostgreSQL `max_connections` (see above)
  - Add more database replicas

#### Slow response times

- **Cause**: Connection pool is saturated or database is overloaded
- **Solutions**:
  - Increase `--db-max-conns` if connection pool is saturated
  - Increase `--db-min-conns` to pre-warm more connections
  - Check if database is the bottleneck (use `EXPLAIN ANALYZE`)
  - Monitor connection usage with `pg_stat_activity`

#### High memory usage

- **Cause**: Too many connections consuming memory
- **Solutions**:
  - Reduce `--db-max-conns` and `--db-min-conns`
  - Reduce `--db-max-conn-lifetime` to recycle connections faster
  - Reduce `--db-max-conn-idle-time` to close idle connections sooner

#### Monitoring Connection Pool

The application logs connection pool configuration at startup:

```text
INFO Connecting to database... host=localhost port=5432 user=web_app database=feedback max_conns=25 min_conns=5
INFO Database connection pool established max_conns=25 min_conns=5 max_conn_lifetime=1h0m0s max_conn_idle_time=30m0s
```

Use PostgreSQL's `pg_stat_activity` to monitor actual connection counts:

```sql
SELECT count(*) FROM pg_stat_activity WHERE datname = 'feedback';
```

## Additional Documentation

- **Database Setup**: See [app/db/README.md][3] for complete database
  documentation

[1]: ./Dockerfile
[2]: ../../docker-compose.dev.yml
[3]: ../db/README.md
[6]: https://github.com/kyleconroy/sqlc
[7]: ./db/migrations/
[8]: https://github.com/amacneil/dbmate
[9]: ./db/queries/
[10]: ./pkgs/db/
