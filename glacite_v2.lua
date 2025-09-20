local teleporter = require("teleport")
local smoothRotation = require("rotations_v2")

-- List of coordinates to teleport to in sequence, with optional yaw, pitch, mine, blockType, radius
local teleportPoints = {
    {x = 24, y = 119, z = 268},  -- No yaw/pitch, no mining
    {x = 57, y = 124, z = 274},  -- No yaw/pitch, no mining
    {x = 91, y = 116, z = 278, yaw = -83.4, pitch = 15.5, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = 86, y = 116, z = 291, yaw = 22.1, pitch = 6.3, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = 67, y = 116, z = 304, yaw = 55.7, pitch = 3.9, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = 54, y = 130, z = 317, yaw = 46.4, pitch = -34.1},
    {x = 45, y = 130, z = 306, yaw = 141.6, pitch = 6.1, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = 39, y = 130, z = 308, yaw = 71.3, pitch = 13.8, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = 28, y = 129, z = 297, yaw = 133.3, pitch = 10.9, mine = false, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = 18, y = 126, z = 309, yaw = 38.4, pitch = 16.0, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = -12, y = 127, z = 320, yaw = 69.4, pitch = 1.7, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = -11, y = 126, z = 328, yaw = -6.5, pitch = 17.0, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = -27, y = 125, z = 330, yaw = 82.8, pitch = 12.2, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = -40, y = 124, z = 320, yaw = 128.1, pitch = 5.3},
    {x = -48, y = 123, z = 312, yaw = 134.4, pitch = 12.5, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = -42, y = 121, z = 297, yaw = -157.4, pitch = 15.2, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = -52, y = 121, z = 277, yaw = 152.7, pitch = 3.6},
    {x = -66, y = 118, z = 275, yaw = 98.7, pitch = 18.0, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = -71, y = 127, z = 257, mine = true, blockType = "block.minecraft.packed_ice", radius = 4},
    {x = -25, y = 120, z = 230, yaw = -120.9, pitch = 9.1},
    {x = -17, y = 129, z = 223, yaw = -130.8, pitch = -33},
    {x = -7, y = 131, z = 237},
    {x = 4, y = 126, z = 244, yaw = -59.5, pitch = 28.5},
}

local routePoints = {}
for _, point in ipairs(teleportPoints) do
    if point.x and point.y and point.z then
        table.insert(routePoints, {x = point.x + 0.5, y = point.y + 1.01, z = point.z + 0.5})
    end
end
-- Close the loop
if #routePoints > 0 then
    table.insert(routePoints, routePoints[1])
end

local currentPointIndex = 1 -- Tracks the current coordinate to teleport to
local isTeleporting = false -- Tracks if teleportation is in progress
local isMining = false -- Tracks if mining is in progress at the current point
local isActivating = false -- Tracks if activating pickaxe ability
local miningState = 0 -- 0: idle/find next, 1: rotating, 2: mining
local currentTargetBlock = nil
local miningTimer = 0
local teleportTimer = 0 -- Tracks ticks since teleport started
local activationTimer = 0 -- Tracks ticks for ability activation
local TELEPORT_TIMEOUT = 800 -- Timeout after ~20 seconds (20 ticks/sec)
local BREAK_TIMEOUT = 55 -- Timeout for breaking a block (~2.5 seconds)
local ACTIVATION_DURATION = 2 -- Hold use for ~0.1 seconds (2 ticks)
local MIN_MANA = 90 -- Minimum mana required for teleport
local delayTimer = 0 -- Tracks ticks for delay between teleports
local TELEPORT_DELAY = 10 -- Delay of ~1 second (20 ticks/sec)
local manaWaitTimer = 0 -- Tracks ticks waiting for mana
local MANA_WAIT_TIMEOUT = 170 -- Timeout after ~10 seconds (20 ticks/sec)
local failedBlocks = {} -- Tracks failed blocks to skip

-- Добавлены переменные для управления таймером
local isAtAnyPoint = false -- Флаг, указывающий что игрок находится на одной из точек
local macroStartTime = nil -- Время начала работы макроса на точке
local totalMacroTime = 0 -- Общее время работы макроса

local function getCurrentPointIndex()
    local pos = player.getPos()
    for i, point in ipairs(teleportPoints) do
        local targetX = point.x + 0.5
        local targetY = point.y + 1
        local targetZ = point.z + 0.5
        local dx = math.abs(pos.x - targetX)
        local dy = math.abs(pos.y - targetY)
        local dz = math.abs(pos.z - targetZ)
        if dx < 0.6 and dy < 1.2 and dz < 0.6 then
            return i
        end
    end
    return nil
end

local function isAtPoint(index)
    local point = teleportPoints[index]
    local targetX = point.x + 0.5
    local targetY = point.y + 1
    local targetZ = point.z + 0.5
    local pos = player.getPos()
    local dx = math.abs(pos.x - targetX)
    local dy = math.abs(pos.y - targetY)
    local dz = math.abs(pos.z - targetZ)
    return dx < 0.6 and dy < 1.2 and dz < 0.6
end

-- Function to find the nearest block of the specified type within radius
local function findNearestBlock(blockType, radius)
    local playerPos = player.getPos()
    local px = math.floor(playerPos.x + 0.5)
    local py = math.floor(playerPos.y + 1.5)
    local pz = math.floor(playerPos.z + 0.5)
    
    local minDistSq = math.huge
    local target = nil
    
    for dx = -math.floor(radius), math.floor(radius) -1 do
        for dy = -math.floor(radius), math.floor(radius) - 1 do
            for dz = -math.floor(radius), math.floor(radius) - 1 do
                local bx = px + dx
                local by = py + dy
                local bz = pz + dz
                local key = math.floor(bx) .. "," .. math.floor(by) .. "," .. math.floor(bz)
                if not failedBlocks[key] and world.getBlock(math.floor(bx), math.floor(by), math.floor(bz)).name == blockType and by >= py - 1 then
                    local distSq = dx*dx + dy*dy + dz*dz
                    if distSq < minDistSq then
                        minDistSq = distSq
                        target = {x = math.floor(bx), y = math.floor(by), z = math.floor(bz)}
                    end
                end
            end
        end
    end
    
    return target
end

register2DRenderer(function(context)
    -- Показывать текст только если игрок находится на одной из точек
    if isAtAnyPoint then
        local scale = context.getWindowScale()
        
        -- Рассчитываем время работы макроса
        local elapsed = totalMacroTime
        if macroStartTime then
            elapsed = elapsed + (os.time() - macroStartTime)
        end
        
        local hours = math.floor(elapsed / 3600)
        local minutes = math.floor((elapsed % 3600) / 60)
        local seconds = elapsed % 60
        local time_str = string.format("%02d:%02d:%02d", hours, minutes, seconds)
        
        local macro_text = "§bGlacite §6macrosing"
        local time_text = "§c" .. time_str
        
        -- Assuming getTextWidth takes the text and returns width for scale=1
        local macro_width = context.getTextWidth("Glacite macrosing")
        local time_width = context.getTextWidth(time_str)
        
        -- Center positions (adjust y for vertical placement, e.g., slightly above and below center)
        local center_x_macro = (scale.width - macro_width + 10) / 2
        local center_y_macro = (scale.height / 2) - 13  -- Slightly above center
        
        local center_x_time = (scale.width - time_width + 10) / 2
        local center_y_time = (scale.height / 2) + 7   -- Slightly below center
        
        local obj2 = {
            x = center_x_macro, y = center_y_macro, scale = 1,
            text = macro_text,
            red = 0, green = 0, blue = 0
        }
        context.renderText(obj2)
        
        local obj3 = {
            x = center_x_time, y = center_y_time, scale = 0.75,
            text = time_text,
            red = 0, green = 0, blue = 0
        }
        context.renderText(obj3)
    end
end)

registerWorldRenderer(function(context)
    if currentTargetBlock then
        local filled = {
            x = currentTargetBlock.x, y = currentTargetBlock.y, z = currentTargetBlock.z,
            red = 255, green = 0, blue = 0, alpha = 140,
            through_walls = false
        }
        context.renderFilled(filled)
    end

    for i = 1, #routePoints - 1 do
        local line = {
            points = {
                [0] = routePoints[i],
                [1] = routePoints[i + 1]
            },
            red = 85, green = 255, blue = 85, alpha = 140,
            line_width = 2, through_walls = false
        }
        context.renderLinesFromPoints(line)

        if isAtPoint(i) then
            local text = {
                x = routePoints[i].x, y = routePoints[i].y + 0.5, z = routePoints[i].z,
                red = 85, green = 255, blue = 85,
                scale = 2,
                text = tostring(i), through_walls = true
            }
            context.renderText(text)
        else
            local text = {
                x = routePoints[i].x, y = routePoints[i].y + 0.5, z = routePoints[i].z,
                red = 85, green = 255, blue = 85,
                scale = 2,
                text = tostring(i), through_walls = false
            }
            context.renderText(text)

        end

        local filled = {
            x = routePoints[i].x - 0.5, y = routePoints[i].y - 1, z = routePoints[i].z,
            red = 85, green = 255, blue = 85, alpha = 140,
            through_walls = false
        }
        context.renderFilled(filled)
    end
end)

registerClientTick(function()
    local teleportComplete = teleporter.update()
    world.setBlock(19, 127, 311, 0)
    
    -- Проверяем, находится ли игрок на одной из точек
    local currentAtPoint = getCurrentPointIndex() ~= nil
    local wasAtAnyPoint = isAtAnyPoint
    
    -- Обновляем состояние нахождения на точке
    isAtAnyPoint = currentAtPoint
    
    -- Управление таймером работы макроса
    if isAtAnyPoint and not wasAtAnyPoint then
        -- Игрок только что прибыл на точку - запускаем таймер
        macroStartTime = os.time()
    elseif not isAtAnyPoint and wasAtAnyPoint then
        -- Игрок ушел с точки - останавливаем таймер и сохраняем общее время
        if macroStartTime then
            totalMacroTime = totalMacroTime + (os.time() - macroStartTime)
            macroStartTime = nil
        end
    end
    
    local item = player.inventory.getStackFromContainer(0)
    if item and isAtAnyPoint then
        player.inventory.closeScreen()
        return
    end

    local ray = player.raycast(5)
    if ray and ray.type == "entity" then
        player.input.setPressedAttack(false) 
        miningState = 0
        miningTimer = 0
        currentTargetBlock = nil
        return
    end

    -- Handle teleportation completion
    if teleportComplete or (isTeleporting and teleportTimer > TELEPORT_TIMEOUT) then
        isTeleporting = false
        teleportTimer = 0
        if isAtPoint(currentPointIndex) then
            delayTimer = TELEPORT_DELAY -- Start delay after teleport
            failedBlocks = {} -- Reset failed blocks after teleport
        end
    end
    
    if isActivating then
        activationTimer = activationTimer + 1
        if activationTimer >= ACTIVATION_DURATION then
            player.input.setPressedUse(false)
            isActivating = false
            isMining = true
            miningState = 0
            miningTimer = 0
        end
    end
    
    if isMining then
        if not isAtPoint(currentPointIndex) then
            isMining = false
            player.input.setPressedAttack(false)
            currentTargetBlock = nil
            miningTimer = 0
            miningState = 0
            return
        end
        local point = teleportPoints[currentPointIndex]
        if miningState == 0 then
            -- Find next target block
            currentTargetBlock = findNearestBlock(point.blockType or "block.minecraft.stone", point.radius or 3)
            if currentTargetBlock == nil then
                -- No more blocks, stop mining, advance, and start teleport
                isMining = false
                player.input.setPressedAttack(false) -- Release attack when no blocks are found
                currentPointIndex = (currentPointIndex % #teleportPoints) + 1
                local nextPoint = teleportPoints[currentPointIndex]
                local currentMana = player.getMana() or 0
                if currentMana >= MIN_MANA or manaWaitTimer > MANA_WAIT_TIMEOUT then
                    player.input.setSelectedSlot(1)
                    if nextPoint.yaw and nextPoint.pitch then
                        teleporter.setTargetTeleport(nextPoint.yaw, nextPoint.pitch)
                    else
                        teleporter.teleportToCoordinates(nextPoint.x, nextPoint.y, nextPoint.z)
                    end
                    isTeleporting = true
                    teleportTimer = 0
                    manaWaitTimer = 0
                else
                    manaWaitTimer = manaWaitTimer + 1
                end
            else
                -- Select slot 1 (0-based) for mining
                player.input.setSelectedSlot(0)
                -- Rotate to the target block
                smoothRotation.rotateToCoordinates(currentTargetBlock.x + 0.5, currentTargetBlock.y + 0.5, currentTargetBlock.z + 0.5)
                miningState = 1
                miningTimer = 0
            end
        elseif miningState == 1 then
            -- Update rotation
            local rotationDone = smoothRotation.update()
            miningTimer = miningTimer + 1
            if rotationDone or miningTimer > 20 then  -- Timeout after ~1 second (20 ticks/sec)
                player.input.setPressedAttack(true) -- Start attack
                miningState = 2
                miningTimer = 0
            end
        elseif miningState == 2 then
            -- Check if block is broken
            miningTimer = miningTimer + 1
            local blockName = world.getBlock(currentTargetBlock.x, currentTargetBlock.y, currentTargetBlock.z).name
            if blockName == "block.minecraft.air" then
                -- Block broken, find next block without releasing attack
                miningState = 0
                miningTimer = 0
                currentTargetBlock = nil
            elseif miningTimer > BREAK_TIMEOUT then
                -- Timeout: release attack, mark as failed, and find next block
                player.input.setPressedAttack(false)
                local key = currentTargetBlock.x .. "," .. currentTargetBlock.y .. "," .. currentTargetBlock.z
                failedBlocks[key] = true
                miningState = 0
                miningTimer = 0
                currentTargetBlock = nil
            end

            local ray = player.raycast(4.5)
            if ray and ray.type == "miss" then
                if currentTargetBlock and isMining then
                    local key = currentTargetBlock.x .. "," .. currentTargetBlock.y .. "," .. currentTargetBlock.z
                    failedBlocks[key] = true
                    player.input.setPressedAttack(true) -- Start attack
                    miningState = 0
                    miningTimer = 0
                    currentTargetBlock = nil
                end
            elseif ray and ray.type == "block" then
                local blockName = world.getBlock(ray.x, ray.y, ray.z).name
                if currentTargetBlock and isMining and blockName ~= "block.minecraft.packed_ice" then
                    local key = currentTargetBlock.x .. "," .. currentTargetBlock.y .. "," .. currentTargetBlock.z
                    failedBlocks[key] = true
                    player.input.setPressedAttack(true) -- Start attack
                    miningState = 0
                    miningTimer = 0
                    currentTargetBlock = nil
                end
            elseif not ray then
                if currentTargetBlock and isMining then
                    local key = currentTargetBlock.x .. "," .. currentTargetBlock.y .. "," .. currentTargetBlock.z
                    failedBlocks[key] = true
                    player.input.setPressedAttack(true) -- Start attack
                    miningState = 0
                    miningTimer = 0
                    currentTargetBlock = nil
                end
            end
        end
    end
    
    if not isTeleporting and not isMining and not isActivating and delayTimer == 0 then
        local atIndex = getCurrentPointIndex()
        if atIndex then
            currentPointIndex = atIndex
            local point = teleportPoints[currentPointIndex]
            local blockType = point.blockType or "block.minecraft.stone"
            local radius = point.radius or 3
            if point.mine and findNearestBlock(blockType, radius) ~= nil then
                isActivating = true
                activationTimer = 0
                player.input.setSelectedSlot(0)
                player.input.setPressedUse(true)
            else
                currentPointIndex = (currentPointIndex % #teleportPoints) + 1
                local nextPoint = teleportPoints[currentPointIndex]
                local currentMana = player.getMana() or 0
                if currentMana >= MIN_MANA or manaWaitTimer > MANA_WAIT_TIMEOUT then
                    player.input.setSelectedSlot(1)
                    if nextPoint.yaw and nextPoint.pitch then
                        teleporter.setTargetTeleport(nextPoint.yaw, nextPoint.pitch)
                    else
                        teleporter.teleportToCoordinates(nextPoint.x, nextPoint.y, nextPoint.z)
                    end
                    isTeleporting = true
                    teleportTimer = 0
                    manaWaitTimer = 0
                else
                    manaWaitTimer = manaWaitTimer + 1
                end
            end
        else
            manaWaitTimer = 0
        end
    end
    
    -- Increment timers
    if isTeleporting then
        teleportTimer = teleportTimer + 1
    end
    if delayTimer > 0 then
        delayTimer = delayTimer - 1
    end
end)

return "§bmacros §aenabled"
