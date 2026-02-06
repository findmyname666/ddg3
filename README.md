# FeedDuck

A production-ready feedback collection and analysis system built with Go,
PostgreSQL, and Docker.

## Overview

FeedDuck is a web application that collects user feedback (positive/negative
sentiment with optional comments) and automatically analyzes it daily, creating
summary reports in Asana. This solution was developed for a DuckDuckGo
interview task and follows similar architectural patterns used at DuckDuckGo:
Azure cloud infrastructure, Docker containerization, and VM-based deployments.

**Note**: This is a best-effort Azure implementation. I had no prior Azure
experience before this project.

## Architecture

### Application Components

#### Feedback Application

The feedback application is a single Go binary with multiple subcommands:

- `feedback web` - HTTP server for collecting feedback submissions
- `feedback analysis` - Daily job that aggregates feedback and creates Asana
  tasks
- `feedback migrate` - Database schema migration management

For more information about the application, see the [feedback application
documentation][4].

#### Nginx

For more information about the nginx configuration, see the [nginx
documentation][6].

#### Database

For more information about the database configuration, see the [database
documentation][5].

### Infrastructure Stack

- **Cloud**: Azure (Resource Groups, Virtual Machines, Key Vault, Container
  Registry)
- **OS**: Ubuntu 22.04 LTS
- **Runtime**: Docker + Docker Compose
- **Web Server**: nginx (reverse proxy, SSL termination, rate limiting)
- **Application**: Go 1.25
- **Database**: PostgreSQL 18
- **SSL**: Let's Encrypt via certbot
- **IaC**: Terraform (modules pattern)
- **VM**: Azure Linux VM (using free tier B2s VM)

## Local testing

Prerequisites:

- Most used tools:
  - Docker and Docker Compose
  - azure-cli (used for Terraform and Azure integration)
  - make
  - openssl
  - Terraform (used for infrastructure provisioning)
- Ports **8080** and **443** available on `127.0.0.1`

More tools are needed for development. Most of them are listed in [flake.nix][7].
Additionally there are configured pre-commit hooks for code formatting and linting.
Pre-commit configuration is in [.pre-commit-config.yaml][1].

### Start the application on localhost

The application can be started with the following commands:

```bash
# Generate self-signed certificates for HTTPS (one-time)
make ssl-dev

# Build docker images and start the containers (PostgreSQL, web app, nginx)
make dev-up
```

It uses [docker-compose.dev.yml][8] to run the application. It is configured to
run on localhost.

Once `make dev-up` finishes, from the host:

- Web app via nginx (recommended): `https://localhost` or
  `https://feedduck.localhost`
- Web app directly (bypassing nginx): `http://127.0.0.1:8080`

The first time you visit the HTTPS URLs your browser will warn about the
self‑signed certificate. This is expected in local development, accept the
warning to continue.

To stop and inspect:

```bash
# View logs
make dev-logs

# Stop services (keeps data)
make dev-down

# Stop services and remove data volumes
make dev-down-volumes
```

### Verify everything is working

1. Visit `https://localhost` (or `https://feedduck.localhost`).
2. Click a sentiment button (😊 or 😞).
3. Optionally add a message.
4. Click "Send Feedback".
5. You should see the thank-you page with ASCII duck art.

To inspect stored feedback in development:

```bash
docker exec -it feedduck-postgres-dev psql -U postgres -d feedback -c "SELECT * FROM feedback ORDER BY created_at DESC LIMIT 10;"
```

For more details on the application, Docker Compose environment, and analysis
job, see the [nginx documentation][6], [feedback app documentation][4] and the
[database documentation][5].

### Seed the database with feedback

The [scripts/db_insert_feedback.sh][9] script can be used to seed the database
with feedback. It is configured to work with the development environment.

```sh
# ./scripts/db_insert_feedback.sh -c feedduck-postgres-dev -p 11 -n 1
Submitting 11 positive feedbacks...
Submitting 1 negative feedbacks...
Done! Submitted '11' positive and '1' negative feedbacks.
Verifying feedback in database...
Verification successful!
Updating feedback created_at to be in the past...
Done!
```

Argument `-c` is optional and is the name of the database container to connect
to. If specified, the script will exec into PostgreSQL container and verify the
feedback was submitted and update the `created_at` timestamp to be in the past
so the analysis job will pick it up.

## Production Deployment

Production deployment is managed by Terraform code under `terraform/environments/prod`:

1. Terraform provisions Azure resources (resource group, networking, Key Vault and
   secrets, container registry, and a Linux VM).
2. Cloud-init and provisioning scripts on the VM install Docker, retrieve secrets
   from Key Vault, and start the containers using `docker-compose.prod.yml`.
3. A systemd timer runs the `feedback analysis` job on a schedule.

For full instructions and module-level details, see the
[Terraform infrastructure documentation][2].

## Operating the Production Stack

After Terraform has finished and the VM is up, the application runs as Docker
containers managed by Docker Compose:

```bash
# SSH to production server
ssh ubuntu@<server-ip-or-name>

# Check service status
cd /opt/feedduck
docker compose -f docker-compose.prod.yml ps

# View logs
docker compose -f docker-compose.prod.yml logs -f web
```

## Troubleshooting

For production issues:

- Check container status and logs on the VM (see "Operating the Production Stack"
  above).
- For application-level behavior and logging, see the [feedback app
  documentation][4].
- For database connectivity and permissions, see the [database documentation][5].
- For nginx and TLS details, see the [nginx documentation][6].
- For infrastructure and VM provisioning, see the [Terraform documentation][2].

For more information, see the [TROUBLESHOOTING.md][3] file.

## Future Enhancements

Given more time, I would first improve observability by exporting application
logs, metrics, and alerts into "monitoring tool of choice" so production issues
can be detected and debugged quickly. I would introduce a CI/CD pipeline that
runs tests and security checks on every change and supports gradual rollouts
(blue‑green or canary) to reduce deployment risk. The VM and application
provisioning could be improved by either aligning with DuckDuckGo's Chef-based
approach or by baking a hardened Ubuntu image with the required tools and
configuration pre-installed. On the data side, I would consider separating the
database into managed infrastructure with automated backups, retention, and
cleanup policies, and further harden the OS (restrict SSH access, disable root
login, minimize open services) to tighten the overall security posture.

[1]: .pre-commit-config.yaml
[2]: terraform/README.md
[3]: TROUBLESHOOTING.md
[4]: app/feedback/README.md
[5]: app/db/README.md
[6]: app/nginx/README.md
[7]: flake.nix
[8]: docker-compose.dev.yml
[9]: scripts/db_insert_feedback.sh
