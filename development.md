# Smart Heritage - Development

## Local Development

For local development, run SQL Server and Mailpit with Docker Compose, and run the FastAPI and Vite development servers locally.

First create and review `.env` as shown in the
[Windows PowerShell Quick Start](README.md#quick-start-local). For the full stack
in containers, use that Quick Start or the Compose section below.

Start the supporting services and create the `app` database:

```bash
docker compose up -d --wait db mailpit
docker compose run --rm db-init
```

SQL Server is exposed on port **14330** of your machine (port 1433 inside the container), so it does not clash with a SQL Server already installed locally.

Then, from the `backend` directory, install the dependencies and prepare the database:

```bash
uv sync
uv run bash scripts/prestart.sh
```

Preparation is a separate step: run it once on a new database and again after
pulling new migrations, before starting FastAPI. The host command above requires
Bash; the PowerShell Quick Start runs Bash inside the backend container instead.

Start the FastAPI development server:

```bash
uv run fastapi dev
```

In another terminal, from the project root, install the frontend dependencies and start the Vite development server:

```bash
bun install
bun run dev
```

Now you can open these URLs:

Frontend development server: <http://localhost:5173>

Backend API: <http://localhost:8000>

Automatic interactive API documentation with Swagger UI: <http://localhost:8000/docs>

Mailpit: <http://localhost:8025>

The frontend development server uses the backend at `http://localhost:8000`, as configured in `frontend/.env`.

### Frontend Served by FastAPI

Build the frontend from the `frontend` directory:

```bash
bun run build
```

The build is written to `backend/app/frontend` and served by FastAPI at <http://localhost:8000>. Rebuild the frontend after making frontend changes.

## Full Stack with Docker Compose

From the repository root, after creating and reviewing `.env`, run these commands
in order. Stop if a command fails:

```powershell
docker compose up -d --wait db mailpit proxy
if ($LASTEXITCODE -ne 0) { throw "Supporting services failed to start." }
docker compose run --rm db-init
if ($LASTEXITCODE -ne 0) { throw "Database creation failed." }
docker compose build backend
if ($LASTEXITCODE -ne 0) { throw "Backend build failed." }
docker compose run --rm backend bash scripts/prestart.sh
if ($LASTEXITCODE -ne 0) { throw "Database preparation failed; do not start the backend." }
docker compose watch backend
```

`db-init` only creates the empty database `app`; it does not create tables or users.
The separate prestart command applies migrations and creates missing roles,
languages and the first superuser. After pulling new migrations, repeat the build
and prestart commands before starting the backend again.

Backend startup only starts FastAPI; it does not run migrations or seed data.
`prestart.sh` checks the existing database in `DATABASE_URL` with `SELECT 1`,
trying up to 10 times with 3 seconds between attempts. If the check fails,
preparation stops before migrations and initial data setup. It never connects to
`master` or creates a database. When running outside Compose, provision the
database first; for Azure SQL Database, use the Azure portal.

If login fails with SQL errors about missing tables, follow the
[preparation troubleshooting note](README.md#troubleshooting-preparation-was-skipped).
Log in with the first superuser credentials from `.env` after preparation succeeds.

Now you can open these URLs:

Application, with the frontend and API served by FastAPI: <http://localhost:8000>

Automatic interactive API documentation with Swagger UI: <http://localhost:8000/docs>

Traefik UI, to see how the routes are being handled by the proxy: <http://localhost:8090>

Mailpit: <http://localhost:8025>

Stop a locally running FastAPI server before starting the Compose backend because both use port `8000`.

**Note**: The first time you start the stack, it might take a minute for all the services to be ready, because SQL Server starts slower than most databases. To monitor it, use `docker compose logs`, or `docker compose logs backend` for the backend service.

## SQL Server

The database is SQL Server 2022 running in the `db` Docker service.

| Setting  | Value                                        |
| -------- | -------------------------------------------- |
| Host     | `localhost`                                  |
| Port     | `14330` (container port 1433)                |
| User     | `sa`                                         |
| Password | `DB_PASSWORD` in `.env`                      |
| Database | `app`                                        |

You can connect with DBeaver or Azure Data Studio using these values.

Notes:

- The `sa` password must satisfy the SQL Server password policy (at least 8 characters, with upper case, lower case, digits and symbols). If it does not, the `db` container exits right after starting.
- Docker needs at least 2 GB of memory available for SQL Server.
- Data is stored in the `app-db-data` volume. To reset the database completely, run `docker compose down -v`.
- Inside the development stack the backend connects to `db:1433`; from your machine (local FastAPI and database clients) use `localhost:14330`. Backend tests use a separately provisioned test instance, never this database.

## Mailpit

[Mailpit](https://mailpit.axllent.org) captures emails sent during local development instead of delivering them. The local backend connects to it at `localhost:1025`, and the Compose backend connects to the `mailpit` service. Captured emails are available at <http://localhost:8025>.

## Docker Compose Files and Environment Variables

The main `compose.yml` file contains the configuration shared by the whole stack. Docker Compose loads it automatically.

The `compose.override.yml` file adds local development settings, such as published ports (including `14330:1433` for SQL Server), Mailpit and mounting the source code as a volume. Docker Compose also loads it automatically and applies it on top of `compose.yml`.

The backend reads local settings from the `.env` file. Docker Compose also uses it for variable interpolation and passes the settings each container needs.

After changing variables, make sure you restart the stack:

```bash
docker compose watch backend
```

## The `.env` File

The `.env` file contains local development defaults, passwords, and other configuration. Its hostnames use `localhost` for processes running on your machine (for example `DATABASE_URL` points to `localhost:14330`). Docker Compose overrides hostnames such as the database and SMTP server with their Compose service names.

Do not store deployment secrets in `.env`. When deploying to Azure, keep secrets (database password, `SECRET_KEY`, superuser password) in Azure Key Vault or in the hosting service's secret settings, and change all the default `changethis` and `Passw0rd!dev` values.

## Continuous Integration

GitHub Actions runs these workflows on pull requests and on pushes to `main`:

- **Test Backend**: starts SQL Server and Mailpit with Docker Compose, creates the database, runs migrations and the Pytest suite.
- **Test Docker Compose**: builds the images, runs migrations and checks the backend and the frontend respond.
- **pre-commit**: runs `prek` for linting and formatting.

All of them must pass before merging a Pull Request.

Deployment is manual. `deploy.yml` targets FastAPI Cloud, not Azure, and runs
only through `workflow_dispatch`; start it only after tests are green for the
same commit. `deploy-docker-compose.yml` is also manual only. Neither workflow
automatically waits for or verifies the test results.

## Isolated Backend Tests

From the repository root, use Docker Compose v2+, Bash and OpenSSL:

```bash
bash scripts/test.sh
# scripts/test-local.sh delegates to the same isolated runner.
```

The runner explicitly selects `compose.test.yml` with a fresh
`smart-heritage-test-<random>` project, its own SQL Server storage and no host
ports. It does not load the development `.env`. It provisions a new `test_*`
database and identity token, migrates only that database, then passes both
`TEST_DATABASE_URL` and `TEST_DATABASE_TOKEN` to the backend tests. Exit and
signal handlers tear down only the test project and its database volume;
`backend/htmlcov` is retained. An uncatchable termination requires manual
cleanup of that test project only.

Do not run tests against an already running development stack. For host-based
tests or focused Pytest options, follow the [backend test instructions](./backend/README.md#backend-tests).
The runner's arguments specify the coverage title rather than Pytest options.

## Pre-commit Hooks and Code Linting

The project uses [prek](https://prek.j178.dev/), a modern alternative to [pre-commit](https://pre-commit.com/), for code linting and formatting.

You can find a file `.pre-commit-config.yaml` with configurations at the root of the project.

### Install `prek` to Run Automatically

`prek` is already part of the dependencies of the project.

From the project root, install the Git hook so that `prek` runs automatically before each commit:

```bash
uv run prek install -f
```

The `-f` flag forces the installation, in case there was already a `pre-commit` hook previously installed.

Now whenever you try to commit, for example with:

```bash
git commit
```

`prek` will check and format the code you are about to commit. If it modifies any files, add those files to Git again before committing.

### Run `prek` Manually

You can also run `prek` manually on all files from the project root:

```bash
uv run prek run --all-files
```
