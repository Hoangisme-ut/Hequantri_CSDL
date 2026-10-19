# Smart Heritage

[![Test Docker Compose](../../actions/workflows/test-docker-compose.yml/badge.svg)](../../actions/workflows/test-docker-compose.yml)
[![Test Backend](../../actions/workflows/test-backend.yml/badge.svg)](../../actions/workflows/test-backend.yml)

Smart Heritage is an iBeacon (Bluetooth Low Energy) based smart tourism system for heritage sites.
When a visitor gets close to an artifact, the mobile app recognizes the nearby beacon and shows
multilingual content (text, images, audio, video) without scanning QR codes. Site managers use a
web admin to manage content, beacons, and statistics.

The backend and web admin are based on the open source
[Full Stack FastAPI Template](https://github.com/fastapi/full-stack-fastapi-template) (MIT license),
adapted to use **SQL Server** instead of PostgreSQL.

## Technology Stack and Features

- ⚡ [**FastAPI**](https://fastapi.tiangolo.com) for the Python backend API.
  - 🧰 [SQLModel](https://sqlmodel.tiangolo.com) for the Python SQL database interactions (ORM).
  - 🔍 [Pydantic](https://docs.pydantic.dev), used by FastAPI, for the data validation and settings management.
  - 💾 [SQL Server 2022](https://www.microsoft.com/sql-server) as the SQL database (Docker container in development, Azure SQL Database when deployed).
- 🚀 [React](https://react.dev) for the web admin.
  - 🧩 Built into the backend application and served by FastAPI on the same domain as the API.
  - 💃 Using TypeScript, hooks, [Vite](https://vitejs.dev), and other parts of a modern frontend stack.
  - 🎨 [Tailwind CSS](https://tailwindcss.com) and [shadcn/ui](https://ui.shadcn.com) for the frontend components.
  - 🤖 An automatically generated frontend client.
  - 🧪 [Playwright](https://playwright.dev) for end-to-end testing.
  - 🦇 Dark mode support.
- 📱 Mobile app for visitors (planned): Flutter with a BLE library to detect iBeacon.
- 🐋 [Docker Compose](https://www.docker.com) for local services.
  - 📞 [Traefik](https://traefik.io) as a reverse proxy.
- 🔒 Secure password hashing by default.
- 🔑 JWT (JSON Web Token) authentication.
- 📫 Email-based password recovery.
- 📬 [Mailpit](https://mailpit.axllent.org) for local email testing during development.
- ✅ Tests with [Pytest](https://pytest.org).
- 🏭 CI (continuous integration) based on GitHub Actions.

### Dashboard Login

![Dashboard login screenshot](img/login.png)

### Dashboard - Admin

![Admin dashboard screenshot](img/dashboard.png)

### Dashboard - Items

![Items dashboard screenshot](img/dashboard-items.png)

### Dashboard - Dark Mode

![Dark mode dashboard screenshot](img/dashboard-dark.png)

### Mailpit - Local Email Testing

![Mailpit screenshot](img/mailpit.png)

### Interactive API Documentation

![API docs](img/docs.png)

## Quick Start (Local)

Requirements: [Docker](https://www.docker.com) (at least 2 GB RAM allocated, required by SQL Server)
and [uv](https://docs.astral.sh/uv/).

```bash
# 1. Review the local settings (SQL Server password, superuser, SMTP)
cat .env

# 2. Start everything
docker compose watch
```

Local services:

| Service              | URL / Address                                   |
| -------------------- | ----------------------------------------------- |
| Web admin and API    | http://localhost:8000                           |
| API docs (Swagger)   | http://localhost:8000/docs                      |
| Mailpit (test email) | http://localhost:8025                           |
| Traefik dashboard    | http://localhost:8090                           |
| SQL Server           | `localhost,14330` (user `sa`, database `app`)   |

SQL Server uses port **14330** on your machine (container port 1433), so it does not clash with a
SQL Server that may already be installed locally. The database password is `DB_PASSWORD` in `.env`.
To inspect the database, connect with a client such as DBeaver or Azure Data Studio.

When testing with a real phone, use the LAN IP of your computer (for example `http://192.168.x.x:8000`).
The Android emulator reaches your computer at `http://10.0.2.2:8000`.

## Backend Development

Backend docs: [backend/README.md](./backend/README.md).

## Frontend Development

Frontend docs: [frontend/README.md](./frontend/README.md).

## Development

General development docs: [development.md](./development.md).

This includes the local FastAPI and Vite workflow, Docker Compose services, `.env` configuration, and more.

## Team Workflow

- Do not push directly to `main`. Create a branch per task (`feature/task-name`) and open a Pull Request.
- CI (GitHub Actions) must pass before merging.

## Release Notes

Check the file [release-notes.md](./release-notes.md).

## License

This project is based on the Full Stack FastAPI Template, licensed under the terms of the MIT license.
