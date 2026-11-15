#! /usr/bin/env bash

set -e
set -x

# Wait for the existing target database to accept queries
python app/backend_pre_start.py

# Run migrations
alembic upgrade head

# Create initial data in DB
python app/initial_data.py
