#!/usr/bin/env bash

set -euo pipefail
# Never trace commands: the test credentials and identity token are secrets.

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v docker >/dev/null
command -v openssl >/dev/null

export TEST_DATABASE_TOKEN
TEST_DATABASE_TOKEN=$(openssl rand -hex 32)
export TEST_DB_PASSWORD
TEST_DB_PASSWORD="Test1!$(openssl rand -hex 16)"
export TEST_SECRET_KEY
TEST_SECRET_KEY=$(openssl rand -hex 32)
export TEST_DATABASE_URL="mssql+pymssql://sa:${TEST_DB_PASSWORD}@db:1433/test_backend"

# A fresh project also gives this run its own network, image and named volume.
test_project="smart-heritage-test-$(openssl rand -hex 8)"
printf 'Isolated test project: %s\n' "$test_project"
compose() {
    docker compose --project-directory "$repo_root" --env-file /dev/null \
        -p "$test_project" -f "$repo_root/compose.test.yml" "$@"
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    if ! compose down --volumes --remove-orphans; then
        echo "Could not remove test project $test_project; clean up that project only." >&2
        if [ "$status" -eq 0 ]; then status=1; fi
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

compose build backend
compose up -d --wait db mailpit
compose run --rm --no-deps backend python scripts/provision_test_database.py
compose run --rm --no-deps -e DATABASE_URL="$TEST_DATABASE_URL" \
    backend bash scripts/prestart.sh
compose run --rm --no-deps backend bash scripts/tests-start.sh "$@"
