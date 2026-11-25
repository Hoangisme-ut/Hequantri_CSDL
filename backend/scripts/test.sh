#!/usr/bin/env bash

set -euo pipefail

# Do not enable shell tracing: test credentials are secrets.

: "${TEST_DATABASE_URL:?Set a dedicated test database URL}"
: "${TEST_DATABASE_TOKEN:?Set the provisioned test database identity token}"

export FASTAPI_ENV=development

# Remove a trailing carriage return from arguments passed from Windows.
pytest_args=()
for arg in "$@"; do
    pytest_args+=("${arg%$'\r'}")
done

# Run all tests when no arguments are supplied.
# Otherwise, forward the supplied arguments directly to pytest.
if ((${#pytest_args[@]} > 0)); then
    coverage run -m pytest "${pytest_args[@]}"
else
    coverage run -m pytest tests/
fi

coverage report
coverage html --title "Smart Heritage Test Coverage"
