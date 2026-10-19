#! /usr/bin/env bash

set -e
set -x

cd backend
FASTAPI_ENV=development uv run python -c "import app.main; import json; print(json.dumps(app.main.app.openapi()))" > ../openapi.json
cd ..
mv openapi.json frontend/
bun run --filter frontend generate-client
# NOTE: the frontend lint is intentionally NOT run here.
# This script only regenerates the API client, which lives in `frontend/src/client`
# and is excluded from Biome anyway. Running `bun run lint` (Biome `--write`) here
# made every caller rewrite the whole frontend tree, which breaks the
# `generate-frontend-sdk` pre-commit hook ("files were modified by this hook")
# and made the Playwright workflow fail before the tests even start.
# Frontend linting is enforced by the dedicated `biome check` pre-commit hook
# and by `bun run lint` / `npm run lint` locally.
