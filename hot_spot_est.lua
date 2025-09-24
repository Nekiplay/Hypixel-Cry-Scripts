
local hotspots = {}

function renderLine(context, x, y, z, x2, y2, z2, red, green, blue, line_width)
context.renderLinesFromPoints({
    points = {
        [0] = { x = x, y = y, z = z },
        [1] = { x = x2, y = y2, z = z2 }
    },
    red = red, green = green, blue = blue, alpha = 140,
    line_width = line_width, through_walls = true
})
end

function renderCircle(context, x, y, z, radius, segments, red, green, blue, line_width)
segments = segments or 32
if segments < 8 then segments = 8 end

    local angleStep = 2 * math.pi / segments
    local prevX = x + math.cos(0) * radius
    local prevZ = z + math.sin(0) * radius

    for i = 1, segments do
        local angle = i * angleStep
        local currentX = x + math.cos(angle) * radius
        local currentZ = z + math.sin(angle) * radius

        renderLine(context, prevX, y, prevZ, currentX, y, currentZ, red, green, blue, line_width)

        prevX = currentX
        prevZ = currentZ
        end
        end


registerClientTick(function()
    local entities = world.getEntities()
    hotspots = {}
    for index, entity in ipairs(entities) do
        if entity ~= nil then
            local entityName = entity.display_name
            if string.find(entityName, "Fishing Speed") then
                table.insert(hotspots, {x = entity.x, y = entity.y, z = entity.z, state="Fishing Speed"})
            elseif string.find(entityName, "Sea Creature Chance") then
                table.insert(hotspots, {x = entity.x, y = entity.y, z = entity.z, state="Sea Creature Chance"})
            elseif string.find(entityName, "Treasure Chance") then
                table.insert(hotspots, {x = entity.x, y = entity.y, z = entity.z, state="Treasure Chance"})
            elseif string.find(entityName, "Double Hook Chance") then
                table.insert(hotspots, {x = entity.x, y = entity.y, z = entity.z, state="Double Hook Chance"})
                end
        end
    end
end)

registerWorldRenderer(function(context)
    for index, hotspot in ipairs(hotspots) do
        local red = 255
        local green = 255
        local blue = 255
        local scale = 3

        if hotspot.state == "Fishing Speed" then
            red = 85
            green = 255
            blue = 255
            scale = 3
        elseif hotspot.state == "Sea Creature Chance" then
            red = 85
            green = 85
            blue = 255
        elseif hotspot.state == "Treasure Chance" then
            red = 255
            green = 220
            blue = 85
            scale = 1.5
        elseif hotspot.state == "Double Hook Chance" then
            red = 85
            green = 85
            blue = 255
            scale = 1.5
        end

        local text = {
            x = hotspot.x, y = hotspot.y, z = hotspot.z,
            red = red, green = green, blue = blue,
            scale = scale,
            text = hotspot.state, through_walls = true
        }
        context.renderText(text)
    end
end)
