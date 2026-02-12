#!/bin/bash
# Connect to Windows PostgreSQL from WSL
export PGPASSWORD="property007"
psql -h 192.168.0.123 -p 5434 -U postgres -d lukens_db
