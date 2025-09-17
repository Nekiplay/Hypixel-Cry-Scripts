local smoothRotation = require("rotations_v2")

local SmoothTeleportation = {}
local isTeleporting = false
local teleportState = 0 -- 0: не активно, 1: поворот, 2: шифт, 3: ПКМ, 4: завершение
local stateTimer = 0

function SmoothTeleportation.teleportToCoordinates(x, y, z)
    isTeleporting = true
    teleportState = 1
    stateTimer = 0
    -- Начинаем поворот сразу после установки цели
    smoothRotation.rotateToCoordinates(x + 0.5, y + 0.5, z + 0.5)
    return true
end

function SmoothTeleportation.setTargetTeleport(yaw, pitch)
    target_x, target_y, target_z = x, y, z
    isTeleporting = true
    teleportState = 1
    stateTimer = 0
    -- Начинаем поворот сразу после установки цели
    smoothRotation.setTargetRotation(yaw, pitch)
    return true
end

function SmoothTeleportation.update()
    if not isTeleporting then return false end
    
    stateTimer = stateTimer + 1
    
    if teleportState == 1 then
        -- Фаза поворота
        local isRotationDone = smoothRotation.update()
        
        if isRotationDone then
            teleportState = 2 -- переходим к нажатию шифта
            stateTimer = 0
        end
        
    elseif teleportState == 2 then
        -- Фаза нажатия шифта
        player.input.setPressedSneak(true)
        
        if stateTimer >= 6 then -- ждем несколько тиков
            teleportState = 3 -- переходим к нажатию ПКМ
            stateTimer = 0
        end
        
    elseif teleportState == 3 then
        -- Фаза нажатия ПКМ (удерживаем шифт)
         player.input.setPressedUse(true)
        
        if stateTimer >= 2 then -- ждем несколько тиков для клика
            teleportState = 4 -- переходим к отпусканию клавиш
            stateTimer = 0
        end
    elseif teleportState == 4 then
        -- Фаза нажатия ПКМ (удерживаем шифт)
        player.input.setPressedSneak(false)

        if stateTimer >= 2 then -- ждем несколько тиков для клика
            teleportState = 5 -- переходим к отпусканию клавиш
            stateTimer = 0
        end
    elseif teleportState == 5 then
        player.input.setPressedUse(false)
        if stateTimer >= 5 then -- ждем один тик
            isTeleporting = false
            teleportState = 0
            stateTimer = 0
            return true -- телепортация завершена
        end
    end
    
    return false -- процесс продолжается
end

return SmoothTeleportation
