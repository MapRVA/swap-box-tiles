#!/bin/bash
# Bootstrap the swap-box OSM database: stream the planet, filter to the
# amenities we care about, import with osm2pgsql, and initialise replication.
#
# pipefail is essential here: the planet is streamed (~80GB) straight into
# osmium, and without it a mid-stream curl failure would go unnoticed because
# osmium just sees EOF, finishes the truncated input, and exits 0 — silently
# importing a partial map. With pipefail, curl's failure aborts the run.
set -euo pipefail

PLANET_URL="${PLANET_URL:-https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf}"
FILTERED=/work/filtered.osm.pbf

# Remove the filtered extract on any exit.
trap 'rm -f "$FILTERED"' EXIT

echo "Streaming planet through osmium tags-filter..."
# -f: fail on HTTP >=400 instead of piping an error page into osmium.
# --retry: ride out transient connection failures (restarts the stream).
curl -fsSL --retry 3 --retry-delay 5 "$PLANET_URL" | \
  osmium tags-filter \
    --input-format=pbf \
    --output-format=pbf \
    --omit-referenced \
    --output="$FILTERED" \
    - \
    n/amenity=public_bookcase,food_sharing,give_box

echo "Filtered file size:"
ls -lh "$FILTERED"

# Guard against an empty/truncated filter result before spending time importing.
if [ ! -s "$FILTERED" ]; then
  echo "ERROR: filtered extract is empty — aborting." >&2
  exit 1
fi

# Count matching nodes in the filtered extract (-e scans the file for an exact
# count). This is what we expect to land in swapbox_nodes.
EXPECTED_NODES=$(osmium fileinfo -e -g data.count.nodes "$FILTERED")
echo "Filtered extract contains ${EXPECTED_NODES} node(s)."
if [ "$EXPECTED_NODES" -eq 0 ]; then
  echo "ERROR: filtered extract has no matching nodes — aborting." >&2
  exit 1
fi

echo "Importing into PostgreSQL..."
# osm2pgsql (2.x) uses --user; it and psql below also read PGHOST/PGPORT/
# PGUSER/PGPASSWORD/PGDATABASE from the environment.
osm2pgsql \
  --create \
  --slim \
  --output=flex \
  --style=/etc/osm2pgsql/filter.lua \
  --extra-attributes \
  --database="$PGDATABASE" \
  --host="$PGHOST" \
  --user="$PGUSER" \
  "$FILTERED"

# Verify the import actually landed rows. Catches silent failures that don't
# surface as a non-zero osm2pgsql exit.
IMPORTED_NODES=$(psql -v ON_ERROR_STOP=1 -tAc "SELECT count(*) FROM swapbox_nodes")
echo "Imported ${IMPORTED_NODES} of ${EXPECTED_NODES} node(s) into swapbox_nodes."
if [ "$IMPORTED_NODES" -eq 0 ]; then
  echo "ERROR: swapbox_nodes is empty after import — aborting." >&2
  exit 1
fi
if [ "$IMPORTED_NODES" -lt "$EXPECTED_NODES" ]; then
  echo "WARNING: imported fewer nodes than the extract contained (${IMPORTED_NODES} < ${EXPECTED_NODES})." >&2
fi

echo "Initializing replication state..."
# Note: osm2pgsql-replication is the Python wrapper and still uses --username.
osm2pgsql-replication init \
  --database="$PGDATABASE" \
  --host="$PGHOST" \
  --username="$PGUSER" \
  --server=https://planet.openstreetmap.org/replication/minute

echo "Done."
