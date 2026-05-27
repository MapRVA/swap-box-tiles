local tables = {}

tables.swapbox_nodes = osm2pgsql.define_node_table('swapbox_nodes', {
    { column = 'version',   type = 'integer', not_null = true },
    { column = 'changeset', type = 'bigint' },
    { column = 'timestamp', sql_type = 'timestamptz' },
    { column = 'user_name', type = 'text' },
    { column = 'uid',       type = 'integer' },
    { column = 'tags',      type = 'jsonb', not_null = true },
    { column = 'geom',      type = 'point', projection = 3857, not_null = true },
})

local target_amenities = {
    public_bookcase = true,
    food_sharing    = true,
    give_box        = true,
}

function osm2pgsql.process_node(object)
    local amenity = object.tags.amenity
    if not amenity or not target_amenities[amenity] then
        return
    end

    tables.swapbox_nodes:insert({
        version   = object.version,
        changeset = object.changeset,
        timestamp = object.timestamp,
        user_name = object.user,
        uid       = object.uid,
        tags      = object.tags,
        geom      = object:as_point(),
    })
end
