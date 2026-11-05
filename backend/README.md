# FastAPI Project - Backend

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

Then, from `./backend/`, install the dependencies, prepare the database, and start the development server:

```console
$ uv sync
$ uv run bash scripts/prestart.sh
$ uv run fastapi dev
```

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

To run the backend and built frontend in Docker Compose:

```console
$ docker compose run --rm backend bash scripts/prestart.sh
$ docker compose watch
```

The application is available at `http://localhost:8000`.

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
No test command provisions, marks, or migrates an existing database automatically.
The GitHub Backend workflow provisions a new test database on its disposable runner.
For pure model/guard tests with no DB fixtures, `pytest --noconftest` can be used
explicitly; it is not a substitute for the integration suite.

To test the backend from the `backend` directory, run:

```console
$ uv run bash scripts/test.sh
```

The tests run with Pytest. Modify existing tests or add new ones in `./backend/tests/`.

If you use GitHub Actions, the tests will run automatically.

### Test a Running Stack

If your stack is already up and you just want to run the tests, you can use:

```bash
docker compose exec backend bash scripts/tests-start.sh
```

The `/app/backend/scripts/tests-start.sh` script calls `pytest`. If you need to pass extra arguments to `pytest`, you can pass them to that command and they will be forwarded.

For example, to stop on first error:

```bash
docker compose exec backend bash scripts/tests-start.sh -x
```

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
