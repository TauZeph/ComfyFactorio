local Market = require 'maps.mountain_fortress_v3.basic_markets'
local Loot = require 'maps.mountain_fortress_v3.loot'
local Task = require 'utils.task'
local Token = require 'utils.token'
local Event = require 'utils.event'
local Terrain = require 'maps.mountain_fortress_v3.terrain'.heavy_functions

local insert = table.insert

local tiles_per_call = 16 --how many tiles are inserted with each call of insert_action
local total_calls
local regen_decoratives = false
local force_chunk = false

local Public = {}

-- Set to false by modules that want to control the on_chunk_generated event themselves.
Public.enable_register_events = true

local function do_tile_inner(tiles, tile, pos)
    if type(tile) == 'string' then
        insert(tiles, {name = tile, position = pos})
    end
end

local function do_tile(y, x, data, shape)
    local pos = {x, y}

    -- local coords need to be 'centered' to allow for correct rotation and scaling.
    local tile = shape(x + 0.5, y + 0.5, data)

    if not data.surface.valid then
        return
    end

    if type(tile) == 'table' then
        do_tile_inner(data.tiles, tile.tile, pos)

        local hidden_tile = tile.hidden_tile
        if hidden_tile then
            insert(data.hidden_tiles, {tile = hidden_tile, position = pos})
        end

        local entities = tile.entities
        if entities then
            for _, entity in ipairs(entities) do
                if not entity.position then
                    entity.position = pos
                end
                insert(data.entities, entity)
            end
        end

        local decoratives = tile.decoratives
        if decoratives then
            for _, decorative in ipairs(decoratives) do
                insert(data.decoratives, decorative)
            end
        end

        local markets = tile.markets
        if markets then
            for _, t in ipairs(markets) do
                if not t.position then
                    t.position = pos
                end
                insert(data.markets, t)
            end
        end

        local treasure = tile.treasure
        if treasure then
            for _, t in ipairs(treasure) do
                if not t.position then
                    t.position = pos
                end
                insert(data.treasure, t)
            end
        end
    else
        do_tile_inner(data.tiles, tile, pos)
    end
end

local function do_row(row, data, shape)
    local y = data.top_y + row
    local top_x = data.top_x
    local tiles = data.tiles

    if not data.surface.valid then
        return
    end

    data.y = y

    for x = top_x, top_x + 31 do
        data.x = x
        local pos = {data.x, data.y}

        -- local coords need to be 'centered' to allow for correct rotation and scaling.
        local tile = shape(x + 0.5, y + 0.5, data)

        if type(tile) == 'table' then
            do_tile_inner(tiles, tile.tile, pos)

            local hidden_tile = tile.hidden_tile
            if hidden_tile then
                insert(data.hidden_tiles, {tile = hidden_tile, position = pos})
            end

            local entities = tile.entities
            if entities then
                for _, entity in ipairs(entities) do
                    if not entity.position then
                        entity.position = pos
                    end
                    insert(data.entities, entity)
                end
            end

            local decoratives = tile.decoratives
            if decoratives then
                for _, decorative in ipairs(decoratives) do
                    if not decorative.position then
                        decorative.position = pos
                    end
                    insert(data.decoratives, decorative)
                end
            end

            local markets = tile.markets
            if markets then
                for _, t in ipairs(markets) do
                    if not t.position then
                        t.position = pos
                    end
                    insert(data.markets, t)
                end
            end

            local treasure = tile.treasure
            if treasure then
                for _, t in ipairs(treasure) do
                    if not t.position then
                        t.position = pos
                    end
                    insert(data.treasure, t)
                end
            end
        else
            do_tile_inner(tiles, tile, pos)
        end
    end
end

local function do_place_treasure(data)
    if not data.surface.valid then
        return
    end

    local surface = data.surface
    local treasure = data.treasure
    local rnd = math.random

    if #treasure == 0 then
        return
    end

    for _, e in ipairs(data.treasure) do
        if rnd(1, 6) == 1 then
            e.chest = 'iron-chest'
        end
        Loot.add(surface, e.position, e.chest)
    end
end

local function do_place_markets(data)
    if not data.surface.valid then
        return
    end

    local markets = data.markets
    local surface = data.surface
    local rnd = math.random
    local abs = math.abs

    if #markets == 0 then
        return
    end

    local pos = markets[rnd(1, #markets)]
    if
        surface.count_entities_filtered {
            area = {{pos.x - 96, pos.y - 96}, {pos.x + 96, pos.y + 96}},
            name = 'market',
            limit = 1
        } == 0
     then
        local market = Market.mountain_market(surface, pos, abs(pos.y) * 0.004)
        market.destructible = false
    end
end

local function do_place_tiles(data)
    if not data.surface.valid then
        return
    end

    data.surface.set_tiles(data.tiles, true)
end

local function do_place_hidden_tiles(data)
    if not data.surface.valid then
        return
    end

    local surface = data.surface
    for _, t in ipairs(data.hidden_tiles) do
        surface.set_hidden_tile(t.position, t.tile)
    end
end

local function do_place_decoratives(data)
    if not data.surface.valid then
        return
    end

    if regen_decoratives then
        data.surface.regenerate_decorative(nil, {{data.top_x / 32, data.top_y / 32}})
    end

    local dec = data.decoratives
    if #dec > 0 then
        data.surface.create_decoratives({check_collision = true, decoratives = dec})
    end
end

local function do_place_entities(data)
    if not data.surface.valid then
        return
    end

    local surface = data.surface
    local entity
    local callback

    for _, e in ipairs(data.entities) do
        if e.collision then
            if surface.can_place_entity(e) then
                entity = surface.create_entity(e)
                if entity and e.direction then
                    entity.direction = e.direction
                end
                if entity and e.force then
                    entity.force = e.force
                end
                if entity and e.callback then
                    local c = e.callback.callback
                    if not c then
                        return
                    end
                    local d = {callback_data = e.callback.data}
                    if not d then
                        callback = Token.get(c)
                        callback(entity)
                        return
                    end
                    callback = Token.get(c)
                    callback(entity, d)
                end
            end
        else
            entity = surface.create_entity(e)
            if entity and e.direction then
                entity.direction = e.direction
            end
            if entity and e.force then
                entity.force = e.force
            end
            if entity and e.callback then
                local c = e.callback.callback
                if not c then
                    return
                end
                local d = {callback_data = e.callback.data}
                if not d then
                    callback = Token.get(c)
                    callback(entity)
                    return
                end
                callback = Token.get(c)
                callback(entity, d)
            end
        end
    end
end

local function run_chart_update(data)
    if not data.surface.valid then
        return
    end

    local x = data.top_x / 32
    local y = data.top_y / 32
    if game.forces.player.is_chunk_charted(data.surface, {x, y}) then
        -- Don't use full area, otherwise adjacent chunks get charted
        game.forces.player.chart(
            data.surface,
            {
                {data.top_x, data.top_y},
                {data.top_x + 1, data.top_y + 1}
            }
        )
    end
end

local function map_gen_action(data)
    local state = data.y

    if state < 32 then
        if not data.surface.valid then
            return
        end

        local shape = Terrain
        if shape == nil then
            return false
        end

        local count = total_calls

        local y = state + data.top_y
        local x = data.x

        local max_x = data.top_x + 32

        data.y = y

        repeat
            count = count - 1

            do_tile(y, x, data, shape)

            x = x + 1

            if x == max_x then
                y = y + 1
                if y == data.top_y + 32 then
                    break
                end
                x = data.top_x
                data.y = y
            end

            data.x = x
        until count == 0

        data.y = y - data.top_y
        return true
    elseif state == 32 then
        do_place_tiles(data)
        data.y = 33
        return true
    elseif state == 33 then
        do_place_hidden_tiles(data)
        data.y = 34
        return true
    elseif state == 34 then
        do_place_entities(data)
        data.y = 35
        return true
    elseif state == 35 then
        do_place_markets(data)
        data.y = 36
        return true
    elseif state == 36 then
        do_place_treasure(data)
        data.y = 37
        return true
    elseif state == 37 then
        do_place_decoratives(data)
        data.y = 38
        return true
    elseif state == 38 then
        run_chart_update(data)
        return false
    end
end

local map_gen_action_token = Token.register(map_gen_action)

--- Adds generation of a Chunk of the map to the queue
-- @param event <table> the event table from on_chunk_generated
function Public.schedule_chunk(event)
    local surface = event.surface
    local shape = Terrain

    if not surface.valid then
        return
    end

    if not shape then
        return
    end

    local area = event.area

    local data = {
        yv = 0,
        xv = 0,
        y = 0,
        x = area.left_top.x,
        area = area,
        top_x = area.left_top.x,
        top_y = area.left_top.y,
        surface = surface,
        tiles = {},
        hidden_tiles = {},
        entities = {},
        decoratives = {},
        markets = {},
        treasure = {}
    }

    if not data.surface.valid then
        return
    end

    Task.queue_task(map_gen_action_token, data, total_calls)
end

--- Generates a Chunk of map when called
-- @param event <table> the event table from on_chunk_generated
function Public.do_chunk(event)
    local surface = event.surface
    local shape = Terrain

    if not surface.valid then
        return
    end

    if not shape then
        return
    end

    local area = event.area

    local data = {
        yv = 0,
        xv = 1,
        area = area,
        top_x = area.left_top.x,
        top_y = area.left_top.y,
        surface = surface,
        tiles = {},
        hidden_tiles = {},
        entities = {},
        decoratives = {},
        markets = {},
        treasure = {}
    }

    if not data.surface.valid then
        return
    end

    for row = 0, 31 do
        do_row(row, data, shape)
    end

    do_place_tiles(data)
    do_place_hidden_tiles(data)
    do_place_entities(data)
    do_place_decoratives(data)
    do_place_markets(data)
    do_place_treasure(data)
end

local do_chunk = Public.do_chunk
local schedule_chunk = Public.schedule_chunk

function Public.init(args)
    if args then
        tiles_per_call = args.tiles_per_call or 16
        regen_decoratives = args.regen_decoratives or false
    end

    total_calls = math.ceil(1024 / tiles_per_call)
end

local function on_chunk(event)
    if force_chunk then
        do_chunk(event)
    elseif event.tick == 0 then
        --do_chunk(event)
    else
        schedule_chunk(event)
    end
end

Event.add(defines.events.on_chunk_generated, on_chunk)
Public.init()

return Public
