local teleporter = require("teleport")
local smoothRotation = require("rotations_v2")

-- List of coordinates to teleport to in sequence, with optional yaw, pitch, mine, blockType, radius
local teleportPoints = {
    {x = 24, y = 119, z = 268},  -- No yaw/pitch, no mining
    {x = 57, y = 124, z = 274},  -- No yaw/pitch, no mining
    {x = 20, y = 118, z = 265, yaw = -83.4, pitch = 15.5, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 22, y = 118, z = 267, yaw = 22.1, pitch = 6.3, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 25, y = 118, z = 269, yaw = 55.7, pitch = 3.9, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 54, y = 130, z = 317, yaw = 46.4, pitch = -34.1},  -- Yaw/pitch, no mining
    {x = 20, y = 118, z = 265, yaw = 141.6, pitch = 6.1, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = 71.3, pitch = 13.8, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {yaw = 133.3, pitch = 10.9, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {yaw = 38.4, pitch = 16.0, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {yaw = 69.4, pitch = 1.7, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = -6.5, pitch = 17.0, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = 82.8, pitch = 12.2, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = 128.1, pitch = 5.3, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = 134.4, pitch = 12.5, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = -157.4, pitch = 15.2, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = 152.7, pitch = 3.6, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = 98.7, pitch = 18.0, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = -71, y = 127, z = 257, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = -120.9, pitch = 9.1, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = -130.8, pitch = -33, mine = true, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = -7, y = 131, z = 237, mine = false, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
    {x = 20, y = 118, z = 265, yaw = -59.6, pitch = 29.8, mine = false, blockType = "block.minecraft.packed_ice", radius = 3.3}, -- Mining with yaw/pitch
}

local currentPointIndex = 1 -- Tracks the current coordinate to teleport to
local isTeleporting = false -- Tracks if teleportation is in progress
local isMining = false -- Tracks if mining is in progress at the current point
local miningState = 0 -- 0: idle/find next, 1: rotating, 2: mining
local currentTargetBlock = nil
local miningTimer = 0
local teleportTimer = 0 -- Tracks ticks since teleport started
local TELEPORT_TIMEOUT = 200 -- Timeout after ~10 seconds (20 ticks/sec)
local MIN_MANA = 90 -- Minimum mana required for teleport
local delayTimer = 0 -- Tracks ticks for delay between teleports
local TELEPORT_DELAY = 10 -- Delay of ~1 second (20 ticks/sec)
local manaWaitTimer = 0 -- Tracks ticks waiting for mana
local MANA_WAIT_TIMEOUT = 170 -- Timeout after ~10 seconds (20 ticks/sec)

-- Function to find the nearest block of the specified type within radius
local function findNearestBlock(blockType, radius)
    local playerPos = player.getPos()
    local px = math.floor(playerPos.x + 0.5)
    local py = math.floor(playerPos.y + 0.5)
    local pz = math.floor(playerPos.z + 0.5)
    
    local minDistSq = math.huge
    local target = nil
    
    for dx = -radius, radius do
        for dy = -radius, radius do
            for dz = -radius, radius do
                local bx = px + dx
                local by = py + dy
                local bz = pz + dz
                if world.getBlock(math.floor(bx), math.floor(by), math.floor(bz)).name == blockType and by >= py then
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

registerClientTick(function()
    local teleportComplete = teleporter.update()
    world.setBlock(19, 127, 311, 0)
    -- Handle teleportation completion
    if teleportComplete or (isTeleporting and teleportTimer > TELEPORT_TIMEOUT) then
        isTeleporting = false
        teleportTimer = 0
        delayTimer = TELEPORT_DELAY -- Start delay after teleport
        local point = teleportPoints[currentPointIndex]
        if point.mine then
            isMining = true
        else
            isMining = false
            player.input.setPressedAttack(false) -- Release attack when exiting mining
            currentPointIndex = currentPointIndex + 1
            if currentPointIndex > #teleportPoints then
                currentPointIndex = 1 -- Loop back to the first coordinate
            end
        end
    end
    
    if isMining then
        local point = teleportPoints[currentPointIndex]
        if miningState == 0 then
            -- Find next target block
            currentTargetBlock = findNearestBlock(point.blockType or "block.minecraft.stone", point.radius or 3)
            if currentTargetBlock == nil then
                -- No more blocks, stop mining and advance to next point
                isMining = false
                player.input.setPressedAttack(false) -- Release attack when no blocks are found
                currentPointIndex = currentPointIndex + 1
                if currentPointIndex > #teleportPoints then
                    currentPointIndex = 1
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
            if blockName == "block.minecraft.air" or miningTimer > 50 then  -- Timeout after ~2.5 seconds
                -- Block broken or timed out, find next block without releasing attack
                miningState = 0
                miningTimer = 0
                currentTargetBlock = nil
            end
        end
    else
        -- Start teleporting to the current coordinate if not already teleporting, mining, or in delay
        if not isTeleporting and delayTimer == 0 then
            local point = teleportPoints[currentPointIndex]
            -- Check mana before teleporting
            local currentMana = player.getMana and player.getMana() or 0
            if currentMana >= MIN_MANA or manaWaitTimer > MANA_WAIT_TIMEOUT then
                -- Select slot 2 (0-based) for teleporting
                player.input.setSelectedSlot(1)
                if point.yaw and point.pitch then
                    -- Use setTargetRotation if yaw and pitch are provided
                    teleporter.setTargetTeleport(point.yaw, point.pitch)
                else
                    -- Otherwise, use rotateToCoordinates
                    teleporter.teleportToCoordinates(point.x, point.y, point.z)
                end
                isTeleporting = true
                teleportTimer = 0
                manaWaitTimer = 0 -- Reset mana wait timer
            else
                -- Increment mana wait timer if mana is insufficient
                manaWaitTimer = manaWaitTimer + 1
            end
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