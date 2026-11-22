# FastAPI Project - Backend

## Visit analytics

Admin-only GET endpoints under `/api/v1/analytics`: `overview`, `visits`,
`top-artifacts`, and `sites`. `views` counts VisitLog rows; `unique_users` counts
distinct recorded user IDs within each result group. These are content views,
not physical visitors, visits to a site, or audio interactions.

Optional `from` and `to` parameters require timezone offsets and use UTC
`[from, to)` boundaries. Omitted boundaries are unbounded. `site_id` filters
using the artifact's **current** site; historical site assignments are not
stored. Daily results contain only days with recorded views and exclude legacy
rows with null timestamps. Overview/rankings without time filters include those
rows. Hidden artifacts/sites remain in historical aggregates. Unique user
counts across groups must not be summed to infer a global unique count.

`top-artifacts` accepts `limit` (1–100); `sites` accepts `skip` and `limit`
(1–200). Each endpoint aggregates in one SQL query instead of loading events.

## Visit log rules

`POST /api/v1/visits/` records **one content view** of an artifact for the
logged-in Visitor/Admin.

- **When one row is written:** the mobile app calls it only when it *shows* the
  artifact content after entering a new beacon zone, not on every BLE signal.
  Backend dedup adds a second guard: the same user and artifact within the last
  300 seconds counts as one view. The repeat call returns 200 with the existing
  row; a new view returns 201. The check runs under a per user/artifact
  transaction lock so concurrent requests cannot create duplicates.
- **Viewing time:** the server does not measure it. `duration_seconds` is
  optional (>= 0), sent by the app (time the content stayed open) and stored
  as is; `null` means unknown. `visited_at` is set by the server in UTC when the
  row is created. `rssi` is optional and informational only.
- **Validation:** the artifact must be visible (active artifact and site, else
  404). A `beacon_id` must be an active beacon attached to that artifact and
  site (404/400). An explicit `language_id` must exist (404) and be enabled
  (400); when omitted it falls back to the user's language, then the default.
- **Analytics:** `views` counts VisitLog rows, see Visit analytics above.

## Role API decision

There is **no separate Role API**. Role is a fixed two-value lookup (`admin`,
`visitor`) seeded during separate database preparation (`app/core/db.py`), so CRUD over it would add attack surface
without a use case. Roles are assigned through the User API
(`POST /users/`, `PATCH /users/{id}` with `role_id`), and user management stays
limited to `is_superuser`. See "User management and Heritage roles" below for
the assignment rules. Revisit only if admins need custom roles or permissions.

## Analytics export

Admin-only, same optional `from`, `to` and `site_id` filters and UTC
semantics as the analytics endpoints above.

- `GET /api/v1/analytics/export/excel` returns `analytics-report.xlsx` with
  sheets: `Tong quan` (overview), `Luot xem theo ngay`, `Thong ke Site`,
  `Top 10 hien vat`, `Theo ngon ngu`.
- `GET /api/v1/analytics/export/pdf` returns the same report as a PDF. It needs
  a Vietnamese-capable TrueType font on the server, otherwise it fails with an
  error.

## Token compatibility and reset replay protection

New JWTs carry `purpose=access` or `purpose=password_reset`. Legacy access
tokens without purpose remain valid with a UUID subject and expiry. Legacy
reset links remain valid with an email subject and expiry, but can be used only
once. Migration `c3d4e5f6a7b8` adds `usedpasswordreset` to record a SHA-256 digest
of the verified JWT signing input; no raw token is stored. Consumption and the
password update commit atomically. Deploy the migration before the application.

Web and Mobile continue using the same token response/body fields. Password
changes do **not** revoke existing access sessions or other unused recovery
links; access tokens expire under the existing policy. Global revocation or
credential-version enforcement requires a separately approved session policy.
Consumed-token records are retained; no automatic destructive cleanup is added.

## Feedback API

All paths below are relative to `/api/v1`. Authenticated Visitors/Admins can
POST `/feedbacks/` with `artifact_id`, `rating` (1–5), and optional `comment`.
The server assigns ownership: a non-empty comment starts as `pending`, while
a rating without a comment is `approved`. The artifact and its site must be
visible. Each user may submit one feedback per artifact; duplicates return 409.

GET `/feedbacks/me` returns the caller's submissions for active artifacts/sites;
`include_inactive=true` includes historical feedback. GET `/feedbacks/{feedback_id}`
permits the owner or an Admin; other users receive 404. PUT on that same path
edits the owner's rating/comment. Editing an approved comment resets it to
`pending`; hidden feedback stays `hidden`. Clearing a comment approves it unless
hidden, and changing only the rating preserves status.

Admin-only GET `/feedbacks/` supports `status`, `artifact_id`, `user_id`, `q`,
`skip`, and `limit`. PATCH `/feedbacks/{feedback_id}/status` sets `pending`,
`approved`, or `hidden`. The legacy `rejected` value remains accepted for
moderation/filtering and maps to `hidden`; it is not a stored status.

The moderation body accepts optional `expected_updated_at`, the last observed
timestamp (or explicit null for an unedited row). A mismatch returns 409 with
no change; reload the feedback before retrying. Omitting the field preserves
moderation without a version check. Editing and moderation share a transaction
lock on the feedback ID.

Public GET `/feedbacks/artifact/{artifact_id}` needs no authentication and returns
approved comments for a visible artifact, with `skip`/`limit` pagination. It
excludes rating-only feedback and does not expose `user_id` or moderation status.
List endpoints default to `skip=0`, `limit=20` and allow at most 100 rows per page.

Migration `b2c3d4e5f6a7` is now a compatibility no-op. Migration `e5f6a7b8c9d0`
drops existing feedback checks/uniqueness before repairs, adds `updated_at` if
missing, then restores rating/status checks and unique `(user_id, artifact_id)`.
It clamps ratings to 1–5, maps `rejected` to `hidden` and other invalid statuses
to `pending`, and keeps the newest duplicate by `created_at` with ID as a
tie-breaker. Before changing/deleting rows, it saves their original values in
`feedback_migration_backup` without overwriting existing backups on retry.
Migration logs report backed-up, changed and deleted row counts; downgrade
retains the backup table for manual recovery.

Migration `9398b7ad0549` refuses to drop a non-empty legacy `item` table. Back it
up first, then explicitly archive or remove its rows before retrying. An empty
table is dropped; a missing table is left alone.

## SQL Server verification for phases 2, 4 and 5

The normal test suite includes `test_backend_sqlserver_flow.py` (API calls
equivalent to Admin/Visitor actions, Unicode round trips, resolve, favorites,
visits, feedback, analytics) and `test_sqlserver_schema.py` (Alembic head,
trusted CHECK constraints, unique/filtered indexes, NVARCHAR and foreign keys).
These are backend integration tests, not browser or Flutter UI tests.

Use the isolated test provisioning/identity checks below, migrate a **fresh**
test database, then run `coverage run -m pytest -p no:cacheprovider tests` and
`coverage report --fail-under=90`. Migration execution and schema inspection
must target that verified test database, never the application database.

Concurrency tests use separate SQL Server connections and widen the former
read/write race windows. Visit deduplication keeps a rolling 300-second window
with a transaction lock per user/artifact. Artifact updates and Beacon
assignment writes share one bounded transaction lock; Language writes share
another. Locks are acquired before reading mutable content rows. This favors
correctness for Admin writes; high-volume write throughput has not been load
tested. Database constraints remain the final protection against uniqueness
violations. Only recognized duplicate constraints are mapped to HTTP 409.

Query-count tests compare pages of 1 and 5 rows: Artifact list uses 6 SELECT
statements in both cases, Favorites/Visit History use 7 in both cases (including auth).
Analytics executes one aggregate query per endpoint. These measurements do not
claim production latency or query-plan improvements.

## Requirements

* [Docker](https://www.docker.com/).
* [uv](https://docs.astral.sh/uv/) for Python package and environment management.

## Local Development

Run the backend locally and connect it to the SQL Server database in Docker Compose.

From the project root, start SQL Server and Mailpit, then ensure the `app` database exists:

```console
$ docker compose up -d --wait db mailpit
$ docker compose run --rm db-init
```

`db-init` only creates the empty database `app`. For initial `.env` setup and
commands for Windows PowerShell, see the [Quick Start](../README.md#quick-start-local).

Then, from `./backend/`, install the dependencies, prepare the database, and start the development server:

```console
$ uv sync
$ uv run bash scripts/prestart.sh
$ uv run fastapi dev
```

Preparation is a separate step: run it once on a new database and again after
pulling new migrations, before starting FastAPI. Backend startup does not run
migrations or seed data. `prestart.sh` checks the existing database in
`DATABASE_URL`, runs `alembic upgrade head`, then creates missing roles, languages
and the first superuser, in that order.
The check only runs `SELECT 1`, with up to 10 attempts and a fixed 3-second delay
between attempts. It stops immediately on success and aborts preparation after the
last failure. It never connects to `master` or creates a database. Locally,
`db-init` provisions the database; on Azure SQL Database, create it in the Azure
portal before preparation. The preparation account does not need database-creation
permissions. Sample heritage data is seeded separately from preparation.

The API is available at `http://localhost:8000`, with automatic interactive docs at `http://localhost:8000/docs`.

### Sample Smart Heritage data

After running the migrations, create the development sample data from `./backend/`:

```console
$ uv run alembic upgrade head
$ uv run python -m app.seed_sample_data
```

The script creates two sites, five artifacts with Vietnamese and English
translations (10 total), three beacons, and 20 Media records. Each artifact has
a shared image, a shared video, and separate Vietnamese/English audio metadata.
Vietnamese is the default language; all demo sites, artifacts and beacons are active.
It uses stable IDs and can be run repeatedly without creating duplicate records.
Rerunning restores demo fields and missing demo records, while preserving unrelated
records. Run this against a development database: it refreshes demo content and
sets the default language to Vietnamese. No accounts are created by this seed.

Media URLs point to generic W3Schools playback samples. The image/video are not
depictions of the artifacts; both audio language entries use the same sample
sound, not translated narration. They require internet access and can be replaced
with your own hosted files for realistic playback testing.

### Shared Web / Mobile demo checks

Point both clients at the same backend/database and sign in using an existing
Admin or Visitor account (media management requires Admin). Web should list:

| Site | Site ID | Artifact codes |
| --- | --- | --- |
| Hoàng thành Thăng Long | `10000000-0000-0000-0000-000000000001` | `HTTL-DOAN-MON`, `HTTL-KINH-THIEN`, `HTTL-HAU-LAU` |
| Văn Miếu – Quốc Tử Giám | `10000000-0000-0000-0000-000000000002` | `VMQT-KHUE-VAN-CAC`, `VMQT-BIA-TIEN-SI` |

All three demo beacons use UUID `FDA50693-A4E2-4FB1-AFCF-C6EB07647825`:

| Major | Minor | Artifact |
| --- | --- | --- |
| 1 | 1 | Đoan Môn |
| 1 | 2 | Điện Kính Thiên |
| 2 | 1 | Khuê Văn Các |

To simulate a Mobile scan without BLE hardware, call the following with an
authenticated bearer token; repeat with `lang=en` and with each major/minor pair:

```text
GET /api/v1/beacons/resolve?proximity_uuid=FDA50693-A4E2-4FB1-AFCF-C6EB07647825&major=1&minor=1&lang=vi
```

Expect the matching artifact, translated title/description, `is_fallback=false`,
and three ordered media entries: shared image, shared video, selected-language
audio. The Admin media list contains all four entries per artifact. Run the seed
again and verify the counts remain 2 sites, 5 artifacts, 10 translations,
3 beacons, 2 languages and 20 media on a fresh database.

## General Workflow

Run backend commands from `./backend/` with `uv run`. Make sure your editor uses the Python interpreter at `.venv/bin/python` in the project root.

Modify or add SQLModel models for data and SQL tables in `./backend/app/models.py`, API endpoints in `./backend/app/api/`, CRUD (Create, Read, Update, Delete) utils in `./backend/app/crud.py`.

## VS Code

There are already configurations in place to run the backend through the VS Code debugger, so that you can use breakpoints, pause and explore variables, etc.

The setup is also already configured so you can run the tests through the VS Code Python tests tab.

## Full Stack with Docker Compose

To run the backend and built frontend in Docker Compose, first create and review
`.env` using the [Quick Start](../README.md#quick-start-local), then run the
commands below in order. Stop if a command fails:

```console
$ docker compose up -d --wait db mailpit proxy
$ docker compose run --rm db-init
$ docker compose build backend
$ docker compose run --rm backend bash scripts/prestart.sh
$ docker compose watch backend
```

After pulling new migrations, repeat the build and prestart commands before
starting the backend. The application is available at `http://localhost:8000`;
log in with `FIRST_SUPERUSER` and `FIRST_SUPERUSER_PASSWORD` from `.env`.
For login failures and missing tables, see
[preparation troubleshooting](../README.md#troubleshooting-preparation-was-skipped).

### Docker Compose Override

The `compose.override.yml` file contains local settings for published ports, source synchronization, automatic image rebuilds, and backend reloads. Docker Compose applies it automatically when you run `docker compose` without an explicit file list.

To open a shell in the backend container:

```console
$ docker compose exec backend bash
```

## Backend Tests

Database tests now fail closed unless `TEST_DATABASE_URL` and
`TEST_DATABASE_TOKEN` identify a separately provisioned SQL Server database.
Never point tests at the application's `DATABASE_URL`. Before running tests:

1. Start a dedicated test SQL Server instance (separate container/storage).
2. Set `TEST_DATABASE_URL` to a **new** `test_*` database on that instance and
   `TEST_DATABASE_TOKEN` to a random 64-character hexadecimal token.
3. Run `uv run python scripts/provision_test_database.py`. This refuses an
   existing database and creates an identity marker only in the new database.
4. Run migrations with `DATABASE_URL` temporarily set to `TEST_DATABASE_URL`
   **only for the migration process**, then restore the application URL.
5. Run the test command below with the two `TEST_DATABASE_*` variables set.

The fixture verifies the database name and marker before importing the app's
engine and again before setup/cleanup. A name alone is not proof of isolation.
The provisioning script refuses to reuse or mark an existing database.
The GitHub Backend workflow provisions a new test database on its disposable runner.
For pure model/guard tests with no DB fixtures, `pytest --noconftest` can be used
explicitly; it is not a substitute for the integration suite.

To test the backend from the `backend` directory, run:

```console
$ uv run bash scripts/test.sh
```

The tests run with Pytest. Modify existing tests or add new ones in `./backend/tests/`.

If you use GitHub Actions, the tests will run automatically.

### Isolated Docker Test Stack

From the repository root, with Docker Compose v2+, Bash and OpenSSL available:

```bash
bash scripts/test.sh
# Equivalent entry point:
bash scripts/test-local.sh
```

These root scripts use only `compose.test.yml` and a fresh
`smart-heritage-test-<random>` project. They do not load the development `.env`,
publish host ports, reuse the application's Compose project, or mount its SQL
Server volume. Each run builds its own backend image, starts SQL Server and
Mailpit, provisions a new `test_backend` database with a random identity token,
migrates that database, and invokes the backend test script with both
`TEST_DATABASE_URL` and `TEST_DATABASE_TOKEN`. The safety checks remain enabled.

On exit, failure, SIGINT or SIGTERM, cleanup removes only that run's containers,
network and test database volume. Coverage HTML remains in `backend/htmlcov`.
If cleanup fails or the process is killed without a catchable signal, remove
only the printed test project using `compose.test.yml`; never clean up the
application project as part of testing. For manual teardown, use the exact
printed `-p` name, `-f compose.test.yml` and `--env-file /dev/null`. Set non-empty
placeholder values for `TEST_DB_PASSWORD`, `TEST_SECRET_KEY`, `TEST_DATABASE_URL`
and `TEST_DATABASE_TOKEN` only to satisfy Compose interpolation during cleanup.

Arguments to these scripts set the coverage report title, not Pytest options.
For a focused Pytest run, use the separately provisioned host test database
procedure above and invoke `uv run coverage run -m pytest tests/ -x` from
`backend/`. Do not run tests inside the development backend container.

### Test Coverage

When the tests run, they generate `htmlcov/index.html`. Open it in your browser to inspect the test coverage.

## Migrations

Make sure you create a revision of your models and upgrade the database with that revision every time you change them. From the `backend` directory, use `uv` to run Alembic against the SQL Server database configured in the root `.env` file:

* Alembic is already configured to import your SQLModel models from `./backend/app/models.py`.

* After changing a model (for example, adding a column), create a revision:

```console
$ uv run alembic revision --autogenerate -m "Add column last_name to User model"
```

* Commit to the git repository the files generated in the alembic directory.

* After creating the revision, run the migration in the database (this is what will actually change the database):

```console
$ uv run alembic upgrade head
```

If you don't want to use migrations at all, uncomment the lines in the file at `./backend/app/core/db.py` that end in:

```python
SQLModel.metadata.create_all(engine)
```

and comment the line in the file `scripts/prestart.sh` that contains:

```console
$ alembic upgrade head
```

If you don't want to start with the default models and want to remove them / modify them, from the beginning, without having any previous revision, you can remove the revision files (`.py` Python files) under `./backend/app/alembic/versions/`. And then create a first migration as described above.

## Email Templates

The email templates are written with [React Email](https://react.email) in `./packages/react-email/`. The `emails` directory holds one component per email and the `ui` directory holds the shared components (layout, heading, button, link, callout).

The rendered HTML in `./backend/app/email-templates/` is generated from those components. It is what the application sends and should not be edited by hand.

To preview the emails while editing them, start the dev server from the root of the project:

```console
$ bun run email:dev
```

Values coming from the backend are declared as Jinja placeholders in the component props, for example `username = "{{ username }}"`. The context for each email is built in `generate_*_email()` in `./backend/app/utils.py`, so a new placeholder needs to be added there too.

Once you are done, regenerate the templates used by the application:

```console
$ bun run email:export
```

## User management and Heritage roles

User management remains restricted to `is_superuser=true`. A user with the
`admin` role can manage Heritage content without becoming a superuser. Role
assignment never promotes a user implicitly. Boolean-only superuser changes
continue to synchronize the role to `admin`/`visitor`; conflicting explicit
assignments return 409 before any mutation. Null roles retain the existing
fallback (superuser -> admin, other users -> visitor). Existing inconsistent
records are not silently migrated by profile/password updates.

Password recovery preserves HTTP 200 and the same generic message for both
registered and unknown addresses, including SMTP failures or missing SMTP
configuration. Delivery failures are logged without recipient/token details;
200 is not a delivery receipt. Failed welcome-email delivery does not undo an
already-created user. Delivery checks are enabled for these two flows without
changing other email endpoints. No automatic mail retry/queue is introduced.

# Media metadata API

All media management endpoints require an authenticated Admin (including the
existing superuser fallback). Paths below are relative to `/api/v1`:

| Method | Path | Behavior |
| --- | --- | --- |
| GET | `/artifacts/{artifact_id}/media` | List all media, ordered by `sort_order` |
| POST | `/artifacts/{artifact_id}/media` | Create metadata; returns 201 |
| GET | `/artifacts/{artifact_id}/media/{media_id}` | Read metadata |
| PUT | `/artifacts/{artifact_id}/media/{media_id}` | Update supplied fields |
| DELETE | `/artifacts/{artifact_id}/media/{media_id}` | Delete metadata |

Example POST body:

```json
{
  "media_type": "audio",
  "url": "https://cdn.example.com/artifacts/introduction.mp3",
  "language_id": null,
  "caption": "Introduction",
  "sort_order": 0
}
```

`media_type` accepts `image` (default), `video`, or `audio`. `url` is required
and must be an absolute HTTP(S) URL of at most 500 characters. `language_id`
may reference an existing language or be null for shared media. PUT preserves
omitted fields; null clears `language_id` or `caption`, but is rejected for
`url`, `media_type`, and `sort_order`. Invalid metadata returns 422; missing
Artifact, language, or Media (including Media belonging to another Artifact)
returns 404. No remote file is fetched, uploaded, or deleted.

`GET /beacons/resolve` includes the saved metadata in `artifact.media`, ordered
by `sort_order`: shared media plus media matching the selected language or the
translation fallback language. Changes and deletions apply on the next resolve.
