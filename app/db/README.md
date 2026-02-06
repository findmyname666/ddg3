# Database Setup and Configuration

This directory contains PostgreSQL container configuration and database
documentation for the feedback application.

The main function of a PostgreSQL container is to run a PostgreSQL database
server that stores and manages application data. Persistent storage is achieved
by mounting a volume. Database roles must be created by a superuser or by a
role that has the `CREATEROLE` privilege. The default postgres user in the
container is a superuser, so it has the necessary privileges to create other
roles.

User names and passwords for the database roles are provided by environment
variables that are set in `docker-compose` files.

User creation is done by the init script `scripts/01-init-docker.sh` that is
executed when the container starts. See section [container
configuration](#container-configuration) below for more information.

Please note that the database container does not run migrations or generate
code. This is done by the `migration` command of the `feedback` application.

See [app/feedback/README.md][1] for more information on the application and
how to run migrations and generate code.

## Security Model

The application uses a **three-user security model** with minimal permissions
to enforce the principle of least privilege.

### Database Users

| User                       | Purpose           | Permissions                            |
| -------------------------- | ----------------- | -------------------------------------- |
| `migration_user`           | Schema migrations | DDL (CREATE, ALTER, DROP)              |
| `web_app`                  | Web application   | feedback: RW, feedback_id_seq: USAGE   |
| `feedback_analysis_app`    | Analysis job      | feedback: RO, report_runs: RW          |

### Why Separate Users?

- **Principle of Least Privilege**: Each app only has access to what it needs
- **Defense in Depth**: If one app is compromised, damage is limited
- **Audit Trail**: Database logs show which app performed which action
- **Compliance**: Meets security best practices for production systems

## Database Code Architecture

### Shared Generated Code

Both applications (web and analysis) use the **same generated code**
for database queries from `db/pkg/db/`.

**Why?**

- Security is enforced at the **database level** via user permissions
- Having Go functions in the binary doesn't grant access - the database will
  reject unauthorized queries
- Simpler maintenance - one set of generated code
- Code reuse - both apps use the same types (e.g., `Feedback`,
  `SentimentType`)

## Production Setup

### Critical Security Rules

1. **NEVER run migrations from application code**
   - Applications use restricted users without DDL permissions
   - Migrations require privileged access
   - Separation prevents accidental schema changes

2. **Store credentials in secrets management**
   - Azure Key Vault, AWS Secrets Manager, HashiCorp Vault, etc.
   - Never commit passwords to git
   - Rotate credentials regularly

3. **Use SSL/TLS in production if database is not on the same VM**
   - Set `sslmode=require` in connection strings
   - Use certificate-based authentication if possible

### Configure Application Secrets

Store user credentials in your secrets management system.

#### 4. Verify Permissions

Test that each user has correct permissions:

```bash
# Test web_app user - should succeed
psql "postgres://web_app:PASSWORD@host:5432/feedback" -c \
  "INSERT INTO feedback (sentiment, message) VALUES ('positive', 'test');"

# Test web_app user - should fail (no access to report_runs)
psql "postgres://web_app:PASSWORD@host:5432/feedback" -c \
  "SELECT * FROM report_runs LIMIT 1;"

# Test feedback_analysis_app - should succeed (read-only on feedback)
psql "postgres://feedback_analysis_app:PASSWORD@host:5432/feedback" -c \
  "SELECT * FROM feedback LIMIT 1;"

# Test feedback_analysis_app - should fail (no write to feedback)
psql "postgres://feedback_analysis_app:PASSWORD@host:5432/feedback" -c \
  "INSERT INTO feedback (sentiment, message) VALUES ('positive', 'test');"
```

## Troubleshooting

### Permission Denied Errors

If application gets "permission denied" errors:

1. Check which user the app is using - configured in the application
   configuration.

2. Connect to the container and database as the postgres user.
   Example: `docker exec -it feedduck-postgres-prod psql -U postgres -d feedback`

3. Verify user permissions:

   ```sql
   SELECT grantee, privilege_type
   FROM information_schema.role_table_grants
   WHERE table_name = 'feedback';
   ```

#### Common issues

- App is using wrong user (check connection string)
- Migrations didn't run (permissions not granted)
- User was created but permissions not granted

### Migration Failures

If migrations fail:

1. Check migration user has DDL permissions
2. Check database connection (network, credentials)
3. Review migration logs for specific errors `docker compose -f
   docker-compose.prod.yml logs migration`
4. Rollback if needed `dbmate rollback`. This may be more complicated in
   production as the database container is not running migrations directly.
   Always test properly in development and staging environments before
   deploying to production.

## Container Configuration

The init script [scripts/01-init-docker.sh`][2] handles database user creation
and depends on the following environment variables:

- `DB_USER_MIGRATION_NAME`
- `DB_USER_MIGRATION_PASSWORD`
- `DB_USER_WEB_NAME`
- `DB_USER_WEB_PASSWORD`
- `DB_USER_ANALYSIS_NAME`
- `DB_USER_ANALYSIS_PASSWORD`

These can be configured in `docker-compose.yml` file.
See [docker-compose.dev.yml][3] for an example.

[1]: ../feedback/README.md
[2]: scripts/01-init-docker.sh
[3]: ../../docker-compose.dev.yml
