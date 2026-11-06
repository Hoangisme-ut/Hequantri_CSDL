#!/usr/bin/env bash

set -e
# Do not enable shell tracing: the test URL and identity token are secrets.

: "${TEST_DATABASE_URL:?Set a dedicated test database URL}"
: "${TEST_DATABASE_TOKEN:?Set the provisioned test database identity token}"

FASTAPI_ENV=development coverage run -m pytest tests/
coverage report
coverage html --title "${@-coverage}"
