#!/bin/sh
set -eu
while true; do
  # --max-diff-size bounds each osm2pgsql apply to a small chunk so peak memory
  # stays under the container limit and progress is committed per chunk. Without
  # it the 500MB default merges a huge batch and OOMs while far behind (e.g. a
  # fresh bootstrap catching up days of minute diffs), making zero progress.
  osm2pgsql-replication update \
    --database="$PGDATABASE" \
    --host="$PGHOST" \
    --username="$PGUSER" \
    --max-diff-size=30 \
    -- \
    --output=flex \
    --style=/etc/osm2pgsql/filter.lua \
    --extra-attributes \
    --slim || echo "Update failed, will retry"
  sleep 60
done
