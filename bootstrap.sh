#!/bin/sh
set -eu

PLANET_URL="${PLANET_URL:-https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf}"
FILTERED=/work/filtered.osm.pbf

echo "Streaming planet through osmium tags-filter..."
curl -sSL "$PLANET_URL" | \
  osmium tags-filter \
    --input-format=pbf \
    --output-format=pbf \
    --output="$FILTERED" \
    - \
    n/amenity=public_bookcase,food_sharing,give_box

echo "Filtered file size:"
ls -lh "$FILTERED"

echo "Importing into PostgreSQL..."
osm2pgsql \
  --create \
  --slim \
  --output=flex \
  --style=/etc/osm2pgsql/filter.lua \
  --extra-attributes \
  --database="$PGDATABASE" \
  --host="$PGHOST" \
  --username="$PGUSER" \
  "$FILTERED"

echo "Initializing replication state..."
osm2pgsql-replication init \
  --database="$PGDATABASE" \
  --host="$PGHOST" \
  --username="$PGUSER" \
  --server=https://planet.openstreetmap.org/replication/minute

echo "Cleaning up filtered file..."
rm -f "$FILTERED"
echo "Done."
