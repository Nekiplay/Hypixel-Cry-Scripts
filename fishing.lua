-- Настройки задержки (в тиках)
local PRESS_DELAY = 5   -- Задержка перед нажатием
local RELEASE_DELAY = 3 -- Задержка перед отжатием

local state = {
    tick = 0,
    phase = "idle", -- "idle", "pressing", "pressed", "releasing"
    targetEntity = nil
}

registerClientTick(function()
    local entities = world.getEntities()
    local foundTarget = false
    
    -- Поиск целевой entity
    for index, entity in ipairs(entities) do
        if entity ~= nil then
            local entityName = entity.name
            if string.find(entityName, "!") or string.find(entityName, "ǃ") or string.find(entityName, "ꜝ") and player.fishHook then
                foundTarget = true
                
                if state.phase == "idle" then
                    state.targetEntity = entity
                    state.phase = "pressing"
                    state.tick = 0
                end
                break
            end
        end
    end
    
    -- Обработка состояний
    if state.phase == "pressing" then
        state.tick = state.tick + 1
        if state.tick >= PRESS_DELAY then

            player.input.silentUse(0)
            player.input.silentUse(1)
            state.phase = "pressed"
            state.tick = 0
        end
    
    elseif state.phase == "pressed" then
        -- Удерживаем нажатие, пока есть цель
        if not foundTarget then
            state.phase = "releasing"
            state.tick = 0
        end
    
    elseif state.phase == "releasing" then
        state.tick = state.tick + 1
        if state.tick >= RELEASE_DELAY then

            player.input.silentUse(0)
            state.phase = "idle"
            state.targetEntity = nil
            state.tick = 0
        end
    
    elseif state.phase == "idle" then
        -- Ничего не делаем, ждем новую цель

    end
end)