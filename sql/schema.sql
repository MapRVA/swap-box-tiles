-- Applied after osm2pgsql bootstrap completes, since these objects
-- reference tables that osm2pgsql creates (swapbox_nodes, osm2pgsql_properties).

CREATE INDEX IF NOT EXISTS swapbox_nodes_geom_idx
    ON swapbox_nodes USING GIST (geom);

CREATE OR REPLACE FUNCTION swapbox_v1(z integer, x integer, y integer)
RETURNS bytea
AS $$
    WITH bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS geom
    ),
    mvt_features AS (
        SELECT
            ST_AsMVTGeom(n.geom, bounds.geom, 4096, 64, true) AS geom,
            n.osm_id,
            n.version,
            n.changeset,
            CASE
                WHEN n.tags->>'amenity' = 'food_sharing'
                 AND n.tags->>'vending'  = 'pet_food' THEN 'give_box'
                ELSE n.tags->>'amenity'
            END AS type,
            ST_Y(ST_Transform(n.geom, 4326)) AS lat,
            ST_X(ST_Transform(n.geom, 4326)) AS lon,
            n.tags::text AS tags_json
        FROM swapbox_nodes n, bounds
        WHERE n.geom && bounds.geom
    )
    SELECT ST_AsMVT(mvt_features, 'swapboxes', 4096, 'geom')
    FROM mvt_features;
$$ LANGUAGE sql STABLE PARALLEL SAFE;

CREATE OR REPLACE FUNCTION freshness()
RETURNS jsonb
AS $$
    SELECT jsonb_build_object(
        'replication_timestamp',
        (SELECT value FROM osm2pgsql_properties
         WHERE property = 'current_timestamp')
    );
$$ LANGUAGE sql STABLE;

GRANT EXECUTE ON FUNCTION public.freshness() TO postgrest_reader;
