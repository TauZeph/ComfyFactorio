local WPT = require 'maps.mountain_fortress_v3.table'

local Public = {}

local max_spill = 60
local math_random = math.random
local math_floor = math.floor
local math_sqrt = math.sqrt

local valid_rocks = {
    ['sand-rock-big'] = true,
    ['rock-big'] = true,
    ['rock-huge'] = true
}

local rock_yield = {
    ['rock-big'] = 1,
    ['rock-huge'] = 2,
    ['sand-rock-big'] = 1
}

local function create_particles(surface, name, position, amount, cause_position)
    local d1 = (-100 + math_random(0, 200)) * 0.0004
    local d2 = (-100 + math_random(0, 200)) * 0.0004

    if cause_position then
        d1 = (cause_position.x - position.x) * 0.025
        d2 = (cause_position.y - position.y) * 0.025
    end

    for i = 1, amount, 1 do
        local m = math_random(4, 10)
        local m2 = m * 0.005

        surface.create_particle(
            {
                name = name,
                position = position,
                frame_speed = 1,
                vertical_speed = 0.130,
                height = 0,
                movement = {
                    (m2 - (math_random(0, m) * 0.01)) + d1,
                    (m2 - (math_random(0, m) * 0.01)) + d2
                }
            }
        )
    end
end

local function mining_chances_ores()
    local data = {
        {name = 'iron-ore', chance = 545},
        {name = 'copper-ore', chance = 545},
        {name = 'coal', chance = 545},
        {name = 'stone', chance = 545},
        {name = 'uranium-ore', chance = 50}
    }
    return data
end

local harvest_raffle_ores = {}
for _, t in pairs(mining_chances_ores()) do
    for _ = 1, t.chance, 1 do
        table.insert(harvest_raffle_ores, t.name)
    end
end

local size_of_ore_raffle = #harvest_raffle_ores

local function get_amount(data)
    local entity = data.entity
    local this = data.this
    local distance_to_center = math_floor(math_sqrt(entity.position.x ^ 2 + entity.position.y ^ 2))
    local type_modifier
    local amount
    local second_amount

    local distance_modifier = 0.25
    local base_amount = 25
    local second_base_amount = 10
    local maximum_amount = 100
    if this.type_modifier then
        type_modifier = this.type_modifier
    end
    if this.rocks_yield_ore_distance_modifier then
        distance_modifier = this.rocks_yield_ore_distance_modifier
    end

    if this.rocks_yield_ore_base_amount then
        base_amount = this.rocks_yield_ore_base_amount
    end
    if this.rocks_yield_ore_maximum_amount then
        maximum_amount = this.rocks_yield_ore_maximum_amount
    end

    type_modifier = rock_yield[entity.name] or type_modifier

    amount = base_amount + (distance_to_center * distance_modifier)
    second_amount = math_floor((second_base_amount + (distance_to_center * distance_modifier)) / 3)
    if amount > maximum_amount then
        amount = maximum_amount
    end
    if second_amount > maximum_amount then
        second_amount = maximum_amount
    end

    local m = (70 + math_random(0, 60)) * 0.01

    amount = math_floor(amount * type_modifier * m * 0.7)

    return amount, second_amount
end

function Public.entity_died_randomness(data)
    local entity = data.entity
    local surface = data.surface
    local harvest

    harvest = harvest_raffle_ores[math.random(1, size_of_ore_raffle)]

    local position = {x = entity.position.x, y = entity.position.y}

    surface.spill_item_stack(position, {name = harvest, count = math_random(1, 5)}, true)

    create_particles(surface, 'shell-particle', position, 64, {x = entity.position.x, y = entity.position.y})
end

local function randomness(data)
    local entity = data.entity
    local player = data.player
    local harvest
    local harvest_amount

    harvest = harvest_raffle_ores[math.random(1, size_of_ore_raffle)]
    harvest_amount = get_amount(data)

    local position = {x = entity.position.x, y = entity.position.y}

    player.surface.create_entity(
        {
            name = 'flying-text',
            position = position,
            text = '+' .. harvest_amount .. ' [img=item/' .. harvest .. ']',
            color = {r = 0, g = 127, b = 33}
        }
    )

    if harvest_amount > max_spill then
        player.surface.spill_item_stack(position, {name = harvest, count = max_spill}, true)
        harvest_amount = harvest_amount - max_spill
        local inserted_count = player.insert({name = harvest, count = harvest_amount})
        harvest_amount = harvest_amount - inserted_count
        if harvest_amount > 0 then
            player.surface.spill_item_stack(position, {name = harvest, count = harvest_amount}, true)
        end
    else
        player.surface.spill_item_stack(position, {name = harvest, count = harvest_amount}, true)
    end

    create_particles(player.surface, 'shell-particle', position, 64, {x = player.position.x, y = player.position.y})
end

function Public.on_player_mined_entity(event)
    local entity = event.entity
    if not entity.valid then
        return
    end
    if not valid_rocks[entity.name] then
        return
    end

    local player = game.players[event.player_index]
    local this = WPT.get()
    if not player then
        return
    end

    event.buffer.clear()

    local data = {
        this = this,
        entity = entity,
        player = player
    }

    randomness(data)
end

return Public
