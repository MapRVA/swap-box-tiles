#!/bin/sh
set -eu
while true; do
  osm2pgsql-replication update \
    --database="$PGDATABASE" \
    --host="$PGHOST" \
    --username="$PGUSER" \
    -- \
    --output=flex \
    --style=/etc/osm2pgsql/filter.lua \
    --extra-attributes \
    --slim || echo "Update failed, will retry"
  sleep 60
done
