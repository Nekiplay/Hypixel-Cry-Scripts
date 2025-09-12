local SmoothRotation = {}
local rotationSpeed = 18
local targetYaw, targetPitch = 0, 0
local currentYaw, currentPitch = 0, 0
local isRotating = false
local completionCallback = nil
local initialYawDiff, initialPitchDiff = nil, nil -- Добавляем эти переменные

-- Установка целевого вращения
function SmoothRotation.setTargetRotation(yaw, pitch)
    targetYaw = yaw
    targetPitch = pitch
    local currentRot = player.getRotation()
    currentYaw = currentRot.yaw or currentRot
    currentPitch = currentRot.pitch or 0
    isRotating = true
    initialYawDiff, initialPitchDiff = nil, nil -- Сбрасываем начальную разницу
    return true
end

-- Плавный поворот к координатам
function SmoothRotation.rotateToCoordinates(x, y, z)
    local rotation = world.getRotation(x, y, z)
    return SmoothRotation.setTargetRotation(rotation.yaw, rotation.pitch)
end

-- Плавный поворот к конкретным значениям yaw и pitch
function SmoothRotation.rotateToYawPitch(yaw, pitch)
    return SmoothRotation.setTargetRotation(yaw, pitch)
end

-- Установка скорости вращения
function SmoothRotation.setRotationSpeed(speed)
    rotationSpeed = math.max(1, math.min(speed, 180))
    return rotationSpeed
end

-- Установка callback функции при завершении
function SmoothRotation.setOnComplete(callback)
    completionCallback = callback
    return true
end

-- Плавное вращение к цели
function SmoothRotation.update()
    if not isRotating then return false end
    
    -- Получаем текущее вращение игрока
    local currentRot = player.getRotation()
    local currentYawRot = currentRot.yaw or currentRot
    local currentPitchRot = currentRot.pitch or 0
    
    -- Вычисляем разницу углов
    local yawDiff = (targetYaw - currentYawRot + 180) % 360 - 180
    local pitchDiff = targetPitch - currentPitchRot
    
    -- Проверяем, достигли ли цели
    if math.abs(yawDiff) < 0.1 and math.abs(pitchDiff) < 0.1 then
        player.setRotation(targetYaw, targetPitch)
        isRotating = false
        
        -- Вызываем callback если установлен
        if completionCallback then
            completionCallback()
        end
        
        return true -- поворот завершен
    end
    
    -- Плавное движение к цели
    local yawStep = math.sign(yawDiff) * math.min(math.abs(yawDiff), rotationSpeed)
    local pitchStep = math.sign(pitchDiff) * math.min(math.abs(pitchDiff), rotationSpeed)
    
    currentYawRot = (currentYawRot + yawStep) % 360
    currentPitchRot = math.max(-90, math.min(90, currentPitchRot + pitchStep))
    
    player.setRotation(currentYawRot, currentPitchRot)
    return false -- поворот продолжается
end

-- Проверка, выполняется ли поворот
function SmoothRotation.isRotating()
    return isRotating
end

-- Принудительная остановка поворота
function SmoothRotation.stop()
    if isRotating then
        isRotating = false
        return true
    end
    return false
end

-- Получение прогресса поворота (0-1)
function SmoothRotation.getProgress()
    if not isRotating then return 1 end
    
    -- Получаем текущее вращение игрока
    local currentRot = player.getRotation()
    local currentYawRot = currentRot.yaw or currentRot
    local currentPitchRot = currentRot.pitch or 0
    
    -- Вычисляем разницу углов
    local yawDiff = (targetYaw - currentYawRot + 180) % 360 - 180
    local pitchDiff = targetPitch - currentPitchRot
    
    -- Вычисляем начальную разницу (сохраняем при старте поворота)
    if not initialYawDiff or not initialPitchDiff then
        local startRot = player.getRotation()
        local startYaw = startRot.yaw or startRot
        local startPitch = startRot.pitch or 0
        
        initialYawDiff = math.abs((targetYaw - startYaw + 180) % 360 - 180)
        initialPitchDiff = math.abs(targetPitch - startPitch)
    end
    
    local totalDiff = math.abs(yawDiff) + math.abs(pitchDiff)
    local initialTotalDiff = initialYawDiff + initialPitchDiff
    
    return math.max(0, math.min(1, 1 - (totalDiff / math.max(initialTotalDiff, 0.1))))
end

-- Функция для получения знака числа
function math.sign(x)
    return x > 0 and 1 or x < 0 and -1 or 0
end

return SmoothRotation