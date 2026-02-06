# Troubleshooting Guide

## General Troubleshooting Steps

These are general troubleshooting steps for the production deployment.

- Connect to the VM reporting the issue (see
  `terraform/environments/prod/outputs.tf` for the public IP address)

```bash
# Connect to the VM
ssh -i ./ssh/id_ed25519_feedduck-prod ubuntu@<public-ip>
```

- Switch to the application directory on the VM

```bash
cd /opt/feedduck
```

- Check if all containers are running

```bash
docker compose -f docker-compose.prod.yml ps

# Expected output: All services should show "healthy"
# - feedduck-postgres-prod (healthy)
# - feedduck-web-prod (healthy)
# - feedduck-nginx-prod (healthy)
```

- Examine logs for errors

```bash
# Check nginx logs
docker compose -f docker-compose.prod.yml logs --tail=100 nginx

# Check web application logs
docker compose -f docker-compose.prod.yml logs --tail=100 web

# Check database logs
docker compose -f docker-compose.prod.yml logs --tail=100 postgres

# Check analysis job logs
journalctl -u feedduck-analysis.service -n 50
```

- Check resource usage

```bash
# Check container CPU and memory usage
docker compose -f docker-compose.prod.yml stats

# VM memory usage
free -h
```

- Check if web app is healthy via its internal health endpoint (no DB check)

```bash
docker compose -f docker-compose.prod.yml exec web wget -q -O- http://localhost:8080/health
```

- Check free disk space. PostgreSQL data are stored in `/mnt/db`.

```bash
df -h
```

## Possible Issues

### 5xx Errors

**Symptoms**: Users see 5xx errors when accessing the site.

**Diagnosis**: Follow the **General Troubleshooting Steps** above.

### Database Related issues

**Symptoms**: 5xx errors when submitting feedback, or errors in the logs
  related to the database.

**Diagnosis**:

- Useful commands:

```bash
# Check if PostgreSQL is running and healthy
docker compose -f docker-compose.prod.yml ps postgres
docker compose -f docker-compose.prod.yml exec postgres pg_isready -U postgres

# Check PostgreSQL logs
docker compose -f docker-compose.prod.yml logs --tail=100 postgres
```

**Possible Causes**:

- PostgreSQL container stopped
- Database credentials mismatch (wrong password or user)
- Database disk full
- Database user lacks required privileges (e.g. "permission denied for table ...")
- Database migrations failed and left the schema in a partial state

**Possible Solutions**:

- Useful commands:

```bash
# Restart PostgreSQL container if stopped
docker compose -f docker-compose.prod.yml restart postgres

# Check disk space
df -h

# If disk is full, try to clean up old Docker images
docker system prune -a

# Check database migrations and permissions
docker compose -f docker-compose.prod.yml logs --tail=200 migration
docker compose -f docker-compose.prod.yml exec postgres psql -U postgres -d feedback -c '\du+'
```

- If the database disk is full, we can increase the disk size and then resize
  the filesystem. The disk is provisioned by Terraform. The database container
  is configured to use the host's `/mnt/db` directory for storage.

- If the database is in a bad state and a restore from backup is needed, see the
  **Database Backup** section below.

- For detailed information on database roles, grants, and migrations, see the
  database documentation in [app/db/README.md][3].

### SSL Certificate Issues

**Symptoms**: HTTPS not working, certificate expired warnings.

**Diagnosis**:

```bash
# Check certificate expiration
sudo certbot certificates

# Check nginx logs
docker compose -f docker-compose.prod.yml logs --tail=100 nginx
```

**Possible Solution**:

```bash
# Renew certificate manually
sudo certbot renew

# Restart nginx to pick up new certificate
docker compose -f docker-compose.prod.yml restart nginx
```

### Scheduled analysis job not running

**Symptoms**: No new Asana tasks being created. The job is expected to run
every 4 hours via a systemd timer.

**Diagnosis**:

```bash
# Check if timer is active
systemctl status feedduck-analysis.timer

# Check last run time
systemctl list-timers feedduck-analysis.timer

# Check job logs
journalctl -u feedduck-analysis.service -n 50

# If needed, trigger timer manually
sudo systemctl restart feedduck-analysis.service
```

**Possible Causes**:

- Asana credentials invalid (wrong token / workspace / project)
- Database connection issues

If Asana-related errors appear in the logs (4xx/5xx responses, invalid token,
etc.), verify that the Asana credentials stored in Key Vault are correct
(see [terraform/README.md][5] for how those secrets are managed).

### High Memory Usage

**Symptoms**: Server running slow, out of memory errors.

**Diagnosis**:

```bash
# Check memory usage
free -h

# Check container memory usage
cd /opt/feedduck
docker compose -f docker-compose.prod.yml stats
```

**Possible Solution**:

```bash
# Restart services to free memory if necessary
docker compose -f docker-compose.prod.yml restart

# If persistent, check database connection pool settings
# Edit docker-compose.prod.yml and reduce DB_MAX_CONNS (or tune via environment)
```

For guidance on sizing and tuning the database connection pool, including
"too many connections" issues and slow queries, see the troubleshooting
section in [app/feedback/README.md][2].

### 6. Azure Key Vault Access Issues (Terraform Deployment)

**Symptoms**: VM cannot retrieve secrets from Key Vault, bootstrap fails.

**Diagnosis**:

```bash
# Connect to the VM
ssh -i ./ssh/id_ed25519_feedduck-prod ubuntu@<public-ip>

# Test managed identity login
az login --identity

# Test Key Vault access (Asana credentials secret created by Terraform)
az keyvault secret show \
  --vault-name <kv-name> \
  --name "feedduck-asana-credentials" \
  --query value -o tsv

# (Optional) Check database passwords secret
az keyvault secret show \
  --vault-name <kv-name> \
  --name "feedduck-database-passwords" \
  --query value -o tsv
```

**Possible Causes**:

- Managed identity not assigned to VM or propagation delay
- Cloud-init / bootstrap script failed before secrets were retrieved

**Possible Solution**:

```bash
# From your local machine, verify role assignment
az role assignment list --scope <key-vault-id> | grep "Key Vault Secrets User"

# Grant access if missing
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee <vm-identity-principal-id> \
  --scope <key-vault-id>

# On the VM, inspect cloud-init / bootstrap logs
ssh -i ./ssh/id_ed25519_feedduck-prod ubuntu@<public-ip>
sudo tail -n 100 /var/log/cloud-init-output.log

# Re-run bootstrap if needed (idempotent)
sudo /opt/feedduck/bootstrap.sh
```

For a deeper explanation of the secrets architecture, managed identity, and
typical Terraform / Key Vault failure modes, see [terraform/README.md][5] and
the compute module documentation in [terraform/modules/compute/README.md][6].

## Emergency Procedures

### Complete Service Restart

```bash
cd /opt/feedduck
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d
```

### Rollback to Previous Version

In this deployment model, container images are built and pushed to Azure
Container Registry by Terraform, and the VM pulls specific tags via
`docker-compose.prod.yml`. To roll back to a known-good version:

1. Identify a previously working image tag for each service in ACR.
2. Update the Terraform configuration or `docker-compose.prod.yml` to point to
   those tags.
3. Re-deploy / restart services on the VM:

```bash
cd /opt/feedduck
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

For details on how images and tags are managed, see [terraform/README.md][5].

### Database Backup

```bash
# Create backup
docker compose -f docker-compose.prod.yml exec postgres \
  pg_dump -U postgres feedback > backup-$(date +%Y%m%d-%H%M%S).sql

# Restore from backup
docker compose -f docker-compose.prod.yml exec -T postgres \
  psql -U postgres feedback < backup-20260207-120000.sql
```

## Service-specific troubleshooting references

This document focuses on common, cross-cutting production issues. For
component-specific troubleshooting and deeper background, see:

- **Top-level overview & how to operate the stack**: [README.md][1]
  (see the **Troubleshooting** and **Operating the Production Stack**
  sections).
- **Web application behaviour, analysis job, and DB connection pool
  tuning**: [app/feedback/README.md][2] (see **Troubleshooting** and
  database connection pool sections).
- **Database users, permissions, and migrations**:
  [app/db/README.md][3].
- **TLS / nginx / HTTP/2+3, certificate layout, and local HTTPS
  issues**: [app/nginx/README.md][4].
- **Terraform deployment, VM bootstrap (cloud-init), managed identity,
  and Key Vault / secret management**: [terraform/README.md][5] and
  [terraform/modules/compute/README.md][6].

[1]: README.md
[2]: app/feedback/README.md
[3]: app/db/README.md
[4]: app/nginx/README.md
[5]: terraform/README.md
[6]: terraform/modules/compute/README.md
