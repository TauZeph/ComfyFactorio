local Event = require 'utils.event'
local Server = require 'utils.server'
local WPT = require 'maps.mountain_fortress_v3.table'
local WD = require 'modules.wave_defense.table'
local ICW = require 'maps.mountain_fortress_v3.icw.main'
local format_number = require 'util'.format_number

local shopkeeper = '[color=blue]Shopkeeper:[/color]'

local random = math.random

local Public = {}

local function shuffle(tbl)
    local size = #tbl
    for i = size, 1, -1 do
        local rand = random(size)
        tbl[i], tbl[rand] = tbl[rand], tbl[i]
    end
    return tbl
end

function Public.get_items()
    local this = WPT.get()

    local threat_cost = 100000
    local health_cost = 30000 * (1 + this.health_upgrades)
    local aura_cost = 30000 * (1 + this.aura_upgrades)
    local xp_point_boost_cost = 30000 * (1 + this.xp_points_upgrade)
    local flamethrower_turrets_cost = 7999 * (1 + this.upgrades.flame_turret.limit)
    local land_mine_cost = 2 * (1 + this.upgrades.landmine.limit)

    local items = {}
    items['clear_threat_level'] = {
        stack = 1,
        value = 'coin',
        price = threat_cost,
        tooltip = '[Wave Defense]:\nReduces the threat level by 50%\nUsable if threat level is too high.\nCan be purchased multiple times.',
        sprite = 'item/computer',
        enabled = true
    }
    items['locomotive_max_health'] = {
        stack = 1,
        value = 'coin',
        price = health_cost,
        tooltip = '[Locomotive Health]:\nUpgrades the train health.\nCan be purchased multiple times.',
        sprite = 'item/computer',
        enabled = true
    }
    items['locomotive_xp_aura'] = {
        stack = 1,
        value = 'coin',
        price = aura_cost,
        tooltip = '[XP Aura]:\nUpgrades the aura that is around the train.\nNote! Reaching breach walls gives more XP.',
        sprite = 'item/computer',
        enabled = true
    }
    items['xp_points_boost'] = {
        stack = 1,
        value = 'coin',
        price = xp_point_boost_cost,
        tooltip = '[XP Points]:\nUpgrades the amount of xp points you get inside the XP aura',
        sprite = 'item/computer',
        enabled = true
    }
    items['flamethrower_turrets'] = {
        stack = 1,
        value = 'coin',
        price = flamethrower_turrets_cost,
        tooltip = 'Upgrades the amount of flamethrowers that can be placed.',
        sprite = 'item/computer',
        enabled = true
    }
    items['land_mine'] = {
        stack = 1,
        value = 'coin',
        price = land_mine_cost,
        tooltip = 'Upgrades the amount of landmines that can be placed.',
        sprite = 'item/computer',
        enabled = true
    }
    items['small-lamp'] = {stack = 1, value = 'coin', price = 5, tooltip = 'Small Sunlight'}
    items['wood'] = {stack = 50, value = 'coin', price = 12, tooltip = 'Some fine Wood'}
    items['iron-ore'] = {stack = 50, value = 'coin', price = 12, tooltip = 'Some chunky iron'}
    items['copper-ore'] = {stack = 50, value = 'coin', price = 12, tooltip = 'Some chunky copper'}
    items['stone'] = {stack = 50, value = 'coin', price = 12, tooltip = 'Some chunky stone'}
    items['coal'] = {stack = 50, value = 'coin', price = 12, tooltip = 'Some chunky coal'}
    items['uranium-ore'] = {stack = 50, value = 'coin', price = 12, tooltip = 'Some chunky uranium'}
    items['land-mine'] = {stack = 1, value = 'coin', price = 25, tooltip = 'Land Boom Danger'}
    items['raw-fish'] = {stack = 1, value = 'coin', price = 4, tooltip = 'Flappy Fish'}
    items['firearm-magazine'] = {stack = 1, value = 'coin', price = 5, tooltip = 'Firearm Pew'}
    items['crude-oil-barrel'] = {stack = 1, value = 'coin', price = 8, tooltip = 'Crude Oil Flame'}
    return items
end

local space = {
    minimal_height = 10,
    top_padding = 0,
    bottom_padding = 0
}

local function addStyle(guiIn, styleIn)
    for k, v in pairs(styleIn) do
        guiIn.style[k] = v
    end
end

local function adjustSpace(guiIn)
    addStyle(guiIn.add {type = 'line', direction = 'horizontal'}, space)
end

local function validate_player(player)
    if not player then
        return false
    end
    if not player.valid then
        return false
    end
    if not player.character then
        return false
    end
    if not player.connected then
        return false
    end
    if not game.players[player.index] then
        return false
    end
    return true
end

local function close_market_gui(player)
    local this = WPT.get()

    local element = player.gui.center
    local data = this.players[player.index].data
    if not data then
        return
    end

    if element and element.valid then
        element = element['market_gui']
        if element and element.valid then
            element.destroy()
        end
        if data.frame and data.frame.valid then
            data.frame.destroy()
            for k, _ in pairs(data) do
                data[k] = nil
            end
        end
    end
end

local function redraw_market_items(gui, player, search_text)
    if not validate_player(player) then
        return
    end
    local this = WPT.get()

    gui.clear()
    shuffle(Public.get_items())

    local inventory = player.get_main_inventory()
    local player_item_count = inventory.get_item_count('coin')

    local items_table = gui.add({type = 'table', column_count = 6})

    local slider_value = math.ceil(this.players[player.index].data.slider.slider_value)
    for name, opts in pairs(Public.get_items()) do
        if not search_text then
            goto continue
        end
        if not search_text.text then
            goto continue
        end
        if not string.lower(name:gsub('-', ' ')):find(search_text.text) then
            goto continue
        end
        local item_count = opts.stack * slider_value
        local item_cost = opts.price * slider_value

        local flow = items_table.add({type = 'flow'})
        flow.style.vertical_align = 'bottom'

        local button =
            flow.add(
            {
                type = 'sprite-button',
                sprite = opts.sprite or 'item/' .. name,
                number = item_count,
                name = name,
                tooltip = opts.tooltip,
                style = 'slot_button',
                enabled = opts.enabled
            }
        )
        flow.add(
            {
                type = 'label',
                caption = format_number(item_cost, true) .. ' coins'
            }
        )

        if player_item_count < item_cost then
            button.enabled = false
        end
        ::continue::
    end
end

local function redraw_coins_left(gui, player)
    if not validate_player(player) then
        return
    end

    gui.clear()
    local inventory = player.get_main_inventory()
    local player_item_count = inventory.get_item_count('coin')

    local coinsleft =
        gui.add(
        {
            type = 'label',
            caption = 'Coins left: ' .. format_number(player_item_count, true)
        }
    )

    adjustSpace(coinsleft)
end

local slot_upgrade_offers = {
    [1] = {'gun-turret', 'gun turret'},
    [2] = {'laser-turret', 'laser turret'},
    [3] = {'artillery-turret', 'artillery turret'},
    [4] = {'flamethrower-turret', 'flamethrower turret'},
    [5] = {'land-mine', 'land mine'}
}

local function slot_upgrade(player, offer_index)
    local this = WPT.get()

    local data = this.players[player.index].data
    if not data then
        return
    end

    local price =
        this.entity_limits[slot_upgrade_offers[offer_index][1]].limit *
        this.entity_limits[slot_upgrade_offers[offer_index][1]].slot_price

    local gain = 1
    if offer_index == 5 then
        price =
            math.ceil(
            (this.entity_limits[slot_upgrade_offers[offer_index][1]].limit / 3) *
                this.entity_limits[slot_upgrade_offers[offer_index][1]].slot_price
        )
        gain = 3
    end

    if slot_upgrade_offers[offer_index][1] == 'flamethrower-turret' then
        price =
            (this.entity_limits[slot_upgrade_offers[offer_index][1]].limit + 1) *
            this.entity_limits[slot_upgrade_offers[offer_index][1]].slot_price
    end

    local coins_removed = player.remove_item({name = 'coin', count = price})
    if coins_removed ~= price then
        if coins_removed > 0 then
            player.insert({name = 'coin', count = coins_removed})
        end
        player.print('Not enough coins.', {r = 0.22, g = 0.77, b = 0.44})
        return false
    end

    this.entity_limits[slot_upgrade_offers[offer_index][1]].limit =
        this.entity_limits[slot_upgrade_offers[offer_index][1]].limit + gain
    game.print(
        player.name .. ' has bought a ' .. slot_upgrade_offers[offer_index][2] .. ' slot for ' .. price .. ' coins!',
        {r = 0.22, g = 0.77, b = 0.44}
    )
    Server.to_discord_bold(
        table.concat {
            player.name .. ' has bought a ' .. slot_upgrade_offers[offer_index][2] .. ' slot for ' .. price .. ' coins!'
        }
    )
    redraw_market_items(data.item_frame, player, data.search_text)
    redraw_coins_left(data.coins_left, player)
end

local function slider_changed(event)
    local player = game.players[event.player_index]
    local this = WPT.get()
    local slider_value

    slider_value = this.players
    if not slider_value then
        return
    end
    slider_value = slider_value[player.index].data
    if not slider_value then
        return
    end
    slider_value = slider_value.slider
    if not slider_value then
        return
    end
    slider_value = slider_value.slider_value
    if not slider_value then
        return
    end
    slider_value = math.ceil(slider_value)
    this.players[player.index].data.text_input.text = slider_value
    redraw_market_items(this.players[player.index].data.item_frame, player, this.players[player.index].data.search_text)
end

local function text_changed(event)
    local this = WPT.get()
    local player = game.players[event.player_index]

    local data = this.players[player.index].data
    if not data then
        return
    end
    if not data.text_input then
        return
    end

    if not data.text_input.text then
        return
    end

    local value = 0
    tonumber(data.text_input.text)
    if not value then
        return
    end
    data.slider.slider_value = value
    redraw_market_items(data.item_frame, player, data.search_text)
end

local function gui_opened(event)
    local this = WPT.get()

    if not event.gui_type == defines.gui_type.entity then
        return
    end

    local entity = event.entity
    if not entity then
        return
    end

    if entity ~= this.market then
        return
    end

    local player = game.players[event.player_index]

    if not validate_player(player) then
        return
    end

    local inventory = player.get_main_inventory()
    local player_item_count = inventory.get_item_count('coin')

    local data = this.players[player.index].data

    if data.frame then
        data.frame = nil
    end
    local frame =
        player.gui.screen.add(
        {
            type = 'frame',
            caption = 'Market',
            direction = 'vertical',
            name = 'market_gui'
        }
    )

    frame.auto_center = true

    player.opened = frame
    frame.style.minimal_width = 500
    frame.style.minimal_height = 250

    local search_table = frame.add({type = 'table', column_count = 2})
    search_table.add({type = 'label', caption = 'Search: '})
    local search_text = search_table.add({type = 'textfield'})

    adjustSpace(frame)

    local pane =
        frame.add {
        type = 'scroll-pane',
        direction = 'vertical',
        vertical_scroll_policy = 'always',
        horizontal_scroll_policy = 'never'
    }
    pane.style.maximal_height = 200
    pane.style.horizontally_stretchable = true
    pane.style.minimal_height = 200
    pane.style.right_padding = 0

    local flow = frame.add({type = 'flow'})

    adjustSpace(flow)

    local slider_frame = frame.add({type = 'table', column_count = 5})

    local left_button = slider_frame.add({type = 'button', caption = '-1', name = 'less'})
    local slider =
        slider_frame.add(
        {
            type = 'slider',
            minimum_value = 1,
            maximum_value = 1e3,
            value = 1
        }
    )

    local right_button = slider_frame.add({type = 'button', caption = '+1', name = 'more'})

    left_button.style.width = 0
    left_button.style.height = 0
    right_button.style.width = 0
    right_button.style.height = 0

    slider_frame.add(
        {
            type = 'label',
            caption = 'Qty:'
        }
    )

    local text_input =
        slider_frame.add(
        {
            type = 'textfield',
            text = 1
        }
    )

    local coinsleft = frame.add({type = 'flow'})

    coinsleft.add(
        {
            type = 'label',
            caption = 'Coins left: ' .. format_number(player_item_count, true)
        }
    )

    this.players[player.index].data.search_text = search_text
    this.players[player.index].data.text_input = text_input
    this.players[player.index].data.slider = slider
    this.players[player.index].data.frame = frame
    this.players[player.index].data.item_frame = pane
    this.players[player.index].data.coins_left = coinsleft

    redraw_market_items(pane, player, search_text)
end

local function gui_click(event)
    local this = WPT.get()
    local wdt = WD.get_table()

    local element = event.element
    local player = game.players[event.player_index]
    if not validate_player(player) then
        return
    end

    if not this.players[player.index] then
        return
    end

    local data = this.players[player.index].data
    if not data then
        return
    end

    if not element.valid then
        return
    end
    local name = element.name

    if name == 'less' then
        local slider_value = this.players[player.index].data.slider.slider_value
        if slider_value > 1 then
            data.slider.slider_value = slider_value - 1
            data.text_input.text = data.slider.slider_value
            redraw_market_items(data.item_frame, player, data.search_text)
        end
        return
    elseif name == 'more' then
        local slider_value = data.slider.slider_value
        if slider_value <= 1e3 then
            data.slider.slider_value = slider_value + 1
            data.text_input.text = data.slider.slider_value
            redraw_market_items(data.item_frame, player, data.search_text)
        end
        return
    end

    if not player.opened then
        return
    end
    if not player.opened.name == 'market' then
        return
    end
    if not data then
        return
    end
    local item = Public.get_items()[name]
    if not item then
        return
    end

    local inventory = player.get_main_inventory()
    local player_item_count = inventory.get_item_count(item.value)
    local slider_value = math.ceil(data.slider.slider_value)
    local cost = (item.price * slider_value)
    local item_count = item.stack * slider_value

    if name == 'clear_threat_level' then
        if wdt.threat <= 10000 then
            return player.print(
                shopkeeper .. ' ' .. player.name .. ', threat is already low!',
                {r = 0.98, g = 0.66, b = 0.22}
            )
        end
        player.remove_item({name = item.value, count = cost})

        game.print(
            shopkeeper ..
                ' ' ..
                    player.name ..
                        ' has bought the clear threat modifier for ' ..
                            cost .. ' coins. Threat level is reduced by 50%!',
            {r = 0.98, g = 0.66, b = 0.22}
        )
        Server.to_discord_bold(
            table.concat {
                player.name ..
                    ' has bought the clear threat modifier for ' .. cost .. ' coins. Threat level is reduced by 50%!'
            }
        )
        this.threat_upgrades = this.threat_upgrades + item_count
        wdt.threat = wdt.threat / 2 * item_count

        redraw_market_items(data.item_frame, player, data.search_text)
        redraw_coins_left(data.coins_left, player)

        return
    end
    if name == 'locomotive_max_health' then
        player.remove_item({name = item.value, count = cost})

        game.print(
            shopkeeper ..
                ' ' ..
                    player.name ..
                        ' has bought the locomotive health modifier for ' ..
                            cost .. ' coins. The train health is now buffed.',
            {r = 0.98, g = 0.66, b = 0.22}
        )
        Server.to_discord_bold(
            table.concat {
                player.name ..
                    ' has bought the locomotive health modifier for ' ..
                        cost .. ' coins. The train health is now buffed.'
            }
        )
        this.locomotive_max_health = this.locomotive_max_health + 2500 * item_count
        local m = this.locomotive_health / this.locomotive_max_health
        this.locomotive.health = 1000 * m
        this.train_upgrades = this.train_upgrades + item_count
        this.health_upgrades = this.health_upgrades + item_count
        rendering.set_text(this.health_text, 'HP: ' .. this.locomotive_health .. ' / ' .. this.locomotive_max_health)

        redraw_market_items(data.item_frame, player, data.search_text)
        redraw_coins_left(data.coins_left, player)

        return
    end
    if name == 'locomotive_xp_aura' then
        player.remove_item({name = item.value, count = cost})

        game.print(
            shopkeeper ..
                ' ' ..
                    player.name ..
                        ' has bought the locomotive xp aura modifier for ' ..
                            cost .. ' coins. The XP aura is now buffed.',
            {r = 0.98, g = 0.66, b = 0.22}
        )
        Server.to_discord_bold(
            table.concat {
                player.name ..
                    ' has bought the locomotive xp aura modifier for ' .. cost .. ' coins. The XP aura is now buffed.'
            }
        )
        this.locomotive_xp_aura = this.locomotive_xp_aura + 5
        this.aura_upgrades = this.aura_upgrades + item_count
        this.train_upgrades = this.train_upgrades + item_count

        if this.circle then
            rendering.destroy(this.circle)
        end
        this.circle =
            rendering.draw_circle {
            surface = game.surfaces[this.active_surface_index],
            target = this.locomotive,
            color = this.locomotive.color,
            filled = false,
            radius = this.locomotive_xp_aura,
            only_in_alt_mode = true
        }

        redraw_market_items(data.item_frame, player, data.search_text)
        redraw_coins_left(data.coins_left, player)

        return
    end

    if name == 'xp_points_boost' then
        player.remove_item({name = item.value, count = cost})

        game.print(
            shopkeeper ..
                ' ' ..
                    player.name ..
                        ' has bought the xp point modifier for ' .. cost .. ' coins. You now gain more XP points.',
            {r = 0.98, g = 0.66, b = 0.22}
        )
        Server.to_discord_bold(
            table.concat {
                player.name ..
                    ' has bought the xp point modifier for ' .. cost .. ' coins. You now gain more XP points.'
            }
        )
        this.xp_points = this.xp_points + 0.5
        this.xp_points_upgrade = this.xp_points_upgrade + item_count
        this.train_upgrades = this.train_upgrades + item_count

        redraw_market_items(data.item_frame, player, data.search_text)
        redraw_coins_left(data.coins_left, player)

        return
    end

    if name == 'flamethrower_turrets' then
        player.remove_item({name = item.value, count = cost})
        if item_count >= 1 then
            game.print(
                shopkeeper .. ' ' .. player.name .. ' has bought a flamethrower-turret slot for ' .. cost .. ' coins.',
                {r = 0.98, g = 0.66, b = 0.22}
            )
            Server.to_discord_bold(
                table.concat {
                    player.name .. ' has bought a flamethrower-turret slot for ' .. cost .. ' coins.'
                }
            )
        else
            game.print(
                shopkeeper ..
                    ' ' ..
                        player.name ..
                            ' has bought ' .. item_count .. ' flamethrower-turret slots for ' .. cost .. ' coins.',
                {r = 0.98, g = 0.66, b = 0.22}
            )
            Server.to_discord_bold(
                table.concat {
                    player.name ..
                        ' has bought ' .. item_count .. ' flamethrower-turret slots for ' .. cost .. ' coins.'
                }
            )
        end
        this.upgrades.flame_turret.limit = this.upgrades.flame_turret.limit + item_count

        redraw_market_items(data.item_frame, player, data.search_text)
        redraw_coins_left(data.coins_left, player)

        return
    end
    if name == 'land_mine' then
        player.remove_item({name = item.value, count = cost})

        if item_count >= 1 then
            game.print(
                shopkeeper .. ' ' .. player.name .. ' has bought a landmine slot for ' .. cost .. ' coins.',
                {r = 0.98, g = 0.66, b = 0.22}
            )
        else
            game.print(
                shopkeeper ..
                    ' ' .. player.name .. ' has bought ' .. item_count .. ' landmine slots for ' .. cost .. ' coins.',
                {r = 0.98, g = 0.66, b = 0.22}
            )
            if cost > 5000 then
                Server.to_discord_bold(
                    table.concat {
                        player.name .. ' has bought ' .. item_count .. ' landmine slots for ' .. cost .. ' coins.'
                    }
                )
            end
        end

        this.upgrades.landmine.limit = this.upgrades.landmine.limit + item_count

        redraw_market_items(data.item_frame, player, data.search_text)
        redraw_coins_left(data.coins_left, player)
        return
    end

    if player_item_count >= cost then
        if player.can_insert({name = name, count = item_count}) then
            player.play_sound({path = 'entity-close/stone-furnace', volume_modifier = 0.65})
            player.remove_item({name = item.value, count = cost})
            local inserted_count = player.insert({name = name, count = item_count})
            if inserted_count < item_count then
                player.play_sound({path = 'utility/cannot_build', volume_modifier = 0.65})
                player.insert({name = item.value, count = cost})
                player.remove_item({name = name, count = inserted_count})
            end
            redraw_market_items(data.item_frame, player, data.search_text)
            redraw_coins_left(data.coins_left, player)
        end
    end
end

local function gui_closed(event)
    local player = game.players[event.player_index]
    local this = WPT.get()

    local type = event.gui_type

    if type == defines.gui_type.custom then
        local data = this.players[player.index].data
        if not data then
            return
        end
        close_market_gui(player)
    end
end

local function inside(pos, area)
    local lt = area.left_top
    local rb = area.right_bottom

    return pos.x >= lt.x and pos.y >= lt.y and pos.x <= rb.x and pos.y <= rb.y
end

local function contains_positions(pos, area)
    if inside(pos, area) then
        return true
    end
    return false
end

local function on_player_changed_position(event)
    local this = WPT.get()
    local player = game.players[event.player_index]
    if not this.players[player.index] then
        return
    end
    local data = this.players[player.index].data

    if data and data.frame and data.frame.valid then
        local position = this.market.position
        local area = {
            left_top = {x = position.x - 10, y = position.y - 10},
            right_bottom = {x = position.x + 10, y = position.y + 10}
        }
        if contains_positions(player.position, area) then
            return
        end
        if not data then
            return
        end
        close_market_gui(player)
    end
end

local function create_market(data, rebuild)
    local surface = data.surface
    local this = data.this

    if rebuild then
        local radius = 1024
        local area = {{x = -radius, y = -radius}, {x = radius, y = radius}}
        for _, entity in pairs(surface.find_entities_filtered {area = area, name = 'market'}) do
            entity.destroy()
        end
        this.market = nil
    end

    local locomotive = this.locomotive_index

    local center_position = {
        x = locomotive.area.left_top.x + (locomotive.area.right_bottom.x - locomotive.area.left_top.x) * 0.5,
        y = locomotive.area.left_top.y + (locomotive.area.right_bottom.y - locomotive.area.left_top.y) * 0.5
    }

    this.market = surface.create_entity {name = 'market', position = center_position, force = 'player'}

    rendering.draw_text {
        text = 'Market',
        surface = surface,
        target = this.market,
        scale = 1.5,
        target_offset = {0, -2},
        color = {r = 0.98, g = 0.66, b = 0.22},
        alignment = 'center'
    }

    this.market.destructible = false

    if not this.loco_surface then
        this.loco_surface = this.locomotive.surface
        return
    end

    local position = this.loco_surface.find_non_colliding_position('market', center_position, 128, 0.5)
    local biters = {
        'big-biter',
        'behemoth-biter',
        'big-spitter',
        'behemoth-spitter'
    }
    local e =
        this.loco_surface.create_entity(
        {name = biters[random(1, 4)], position = position, force = 'player', create_build_effect_smoke = false}
    )
    e.ai_settings.allow_destroy_when_commands_fail = false
    e.ai_settings.allow_try_return_to_spawner = false

    for x = center_position.x - 5, center_position.x + 5, 1 do
        for y = center_position.y - 5, center_position.y + 5, 1 do
            if math.random(1, 2) == 1 then
                this.loco_surface.spill_item_stack(
                    {x + math.random(0, 9) * 0.1, y + math.random(0, 9) * 0.1},
                    {name = 'raw-fish', count = 1},
                    false
                )
            end
            this.loco_surface.set_tiles({{name = 'blue-refined-concrete', position = {x, y}}}, true)
        end
    end
    for x = center_position.x - 3, center_position.x + 3, 1 do
        for y = center_position.y - 3, center_position.y + 3, 1 do
            if math.random(1, 2) == 1 then
                this.loco_surface.spill_item_stack(
                    {x + math.random(0, 9) * 0.1, y + math.random(0, 9) * 0.1},
                    {name = 'raw-fish', count = 1},
                    false
                )
            end
            this.loco_surface.set_tiles({{name = 'cyan-refined-concrete', position = {x, y}}}, true)
        end
    end
end

local function place_market()
    local this = WPT.get()
    local icw_table = ICW.get_table()
    if not this.locomotive then
        return
    end

    if not this.locomotive.valid then
        return
    end

    local unit_surface = this.locomotive.unit_number
    local surface = game.surfaces[icw_table.wagons[unit_surface].surface.index]

    local data = {
        this = this,
        surface = surface
    }
    if not this.market then
        create_market(data)
    elseif not this.market.valid then
        create_market(data, true)
    end
end

local function on_tick()
    if game.tick % 30 == 0 then
        place_market()
    end
end

Event.on_nth_tick(5, on_tick)
Event.add(defines.events.on_gui_click, gui_click)
Event.add(defines.events.on_gui_opened, gui_opened)
Event.add(defines.events.on_gui_value_changed, slider_changed)
Event.add(defines.events.on_gui_text_changed, text_changed)
Event.add(defines.events.on_gui_closed, gui_closed)
Event.add(defines.events.on_player_changed_position, on_player_changed_position)

return Public
