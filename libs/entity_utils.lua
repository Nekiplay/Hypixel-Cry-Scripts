local entity = {}

local function parseHealthValue(healthStr)
    if not healthStr then return 0 end
    
    healthStr = tostring(healthStr):gsub(",", ""):gsub(" ", "")
    
    -- Обрабатываем миллионы (M)
    if string.find(healthStr, "M") then
        local num = tonumber(healthStr:gsub("M", "")) or 0
        return math.floor(num * 1000000)
    end
    
    -- Обрабатываем тысячи (K)
    if string.find(healthStr, "K") then
        local num = tonumber(healthStr:gsub("K", "")) or 0
        return math.floor(num * 1000)
    end
    
    -- Обрабатываем обычные числа с точками (например: 1.000 -> 1000)
    if string.find(healthStr, "%.") then
        local parts = {}
        for part in string.gmatch(healthStr, "[^.]+") do
            table.insert(parts, part)
        end
        if #parts >= 2 then
            -- Если после точки 3 цифры (формат 1.000), объединяем
            if string.len(parts[2]) == 3 then
                healthStr = parts[1] .. parts[2]
            else
                -- Иначе это десятичная дробь, оставляем как есть
                healthStr = parts[1] .. "." .. parts[2]
            end
        end
    end
    
    return tonumber(healthStr) or 0
end

-- Функция для форматирования здоровья для отображения
local function formatHealthForDisplay(health)
    if health >= 1000000 then
        return string.format("%.1fM", health / 1000000)
    elseif health >= 1000 then
        return string.format("%.1fK", health / 1000)
    else
        return tostring(math.floor(health))
    end
end

-- Функция для извлечения здоровья из имени сущности
function entity.getEntityHealthFromName(entity)
    if not entity or not entity.display_name then return "N/A" end
    
    local entityName = entity.display_name
    
    -- Паттерны для поиска здоровья в разных форматах
    local patterns = {
        "([%d%.%,]+[MK]?)/([%d%.%,]+[MK]?)❤", -- 1.000/2.000❤ или 1M/2❤M
        "([%d%.%,]+[MK]?)/([%d%.%,]+[MK]?)",   -- 1.000/2.000 или 1M/2M
        "(%d+)/(%d+)❤",                       -- 1000/2000❤
        "(%d+)/(%d+)"                          -- 1000/2000
    }
    
    for _, pattern in ipairs(patterns) do
        local currentHealthStr, maxHealthStr = string.match(entityName, pattern)
        if currentHealthStr and maxHealthStr then
            local currentHealth = parseHealthValue(currentHealthStr)
            local maxHealth = parseHealthValue(maxHealthStr)
            
            if currentHealth > 0 and maxHealth > 0 then
                return currentHealth, maxHealth
            end
        end
    end
    
    return -1, -1
end

return entity