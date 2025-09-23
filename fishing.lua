local PRESS_DELAY = 1   -- Задержка перед нажатием
local ABILITY_DELAY = 24   -- Задержка перед нажатием способности
local ABILITY_RANGE = 5 -- Растояние способности для убийства
local RELEASE_DELAY = 1 -- Задержка перед отжатием
local ENTITY_CHECK_DELAY = 2 -- Задержка следующей проверки что сущность есть рядом
local ENTITY_SPAWN_DELAY = 9 -- Задержка проверки того что сущность появилась
local PREFIX = "§7[§6Hypixel Cry§7]" -- Префикс для чата
local MODE = "Normal" -- "OneShot", "Normal"

local FISHGROD_SLOT = 0
local ABILITY_SLOT = 1

local state = {
    tick = 0,
    phase = "idle", -- "idle", "pressing", "pressed", "ability", "releasing"
    targetEntity = nil
}

local caught = 0
local abilities = 0
local killed = 0

local macroStartTime = nil -- Время начала работы макроса на точке
local totalMacroTime = 0 -- Общее время работы макроса
macroStartTime = os.time()

local started = false

register2DRenderer(function(context)
    local scale = context.getWindowScale()

    local elapsed = totalMacroTime
    if macroStartTime then
        elapsed = elapsed + (os.time() - macroStartTime)
    end
        
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = elapsed % 60
    local time_str = string.format("%02d:%02d:%02d", hours, minutes, seconds)

    local title_text = "§6AFK Fishing"
    local abilities_text = "§cAbilities: " .. tostring(abilities)
    local caught_text = "§bCaught: " .. tostring(caught)
    local killed_text = "§cKilled: " .. tostring(killed)
    local time_text = "§f" .. time_str

    local title_width = context.getTextWidth(title_text)
    local abilities_width = context.getTextWidth(abilities_text)
    local caught_width = context.getTextWidth(caught_text)
    local killed_width = context.getTextWidth(killed_text)
    local time_width = context.getTextWidth(time_text)
        
    -- Center positions (adjust y for vertical placement, e.g., slightly above and below center)
    local center_x_title = (scale.width - title_width) / 2
    local center_y_title = (scale.height / 2) - 25  -- Slightly above cent

    local center_x_abilities = (scale.width - abilities_width) / 2
    local center_y_abilities = (scale.height / 2) - 15  -- Slightly above cent

    local center_x_caught = (scale.width - caught_width) / 2
    local center_y_caught = (scale.height / 2) + 5  -- Slightly above center

    local center_x_killed = (scale.width - killed_width) / 2
    local center_y_killed = (scale.height / 2) + 15

    local center_x_time = (scale.width - time_width) / 2
    local center_y_time = (scale.height / 2) + 26  -- Slightly above cent
        
        
    local obj0 = {
        x = center_x_title, y = center_y_title, scale = 1,
        text = title_text,
        red = 0, green = 0, blue = 0
    }
    context.renderText(obj0)

    local obj1 = {
        x = center_x_abilities, y = center_y_abilities, scale = 1,
        text = abilities_text,
        red = 0, green = 0, blue = 0
    }
    context.renderText(obj1)

    local obj2 = {
        x = center_x_caught, y = center_y_caught, scale = 1,
        text = caught_text,
        red = 0, green = 0, blue = 0
    }
    context.renderText(obj2)

    local obj3 = {
        x = center_x_killed, y = center_y_killed, scale = 1,
        text = killed_text,
        red = 0, green = 0, blue = 0
    }
    context.renderText(obj3)

    local obj4 = {
        x = center_x_time, y = center_y_time, scale = 1,
        text = time_text,
        red = 0, green = 0, blue = 0
    }
    context.renderText(obj4)
    context.renderText(obj3)
end)

local trackedEntities = {}

-- Функция для проверки наличия нужной сущности поблизости
local function hasTargetEntityNearby()
    local entities = world.getEntities()
    local currentEntities = {}
    local foundAny = false
    
    -- Собираем все текущие сущности
    for index, entity in ipairs(entities) do
        if entity ~= nil then
            local entityName = entity.display_name
            local distance = entity.distance_to_player

            -- Проверяем наличие "Lv" в имени и расстояние до игрока
            if entityName and string.find(entityName, "Lv") and distance <= ABILITY_RANGE * ABILITY_RANGE and
               entity.uuid ~= player.entity.uuid and 
               entity.type ~= "entity.minecraft.experience_orb" and 
               entity.type ~= "entity.minecraft.fishing_bobber" and 
               entity.type ~= "entity.minecraft.item" then
                
                currentEntities[entity.uuid] = true
                foundAny = true
                
                -- Если это новая сущность, добавляем в отслеживаемые
                if not trackedEntities[entity.uuid] then
                    trackedEntities[entity.uuid] = true
                end
            end
        end
    end
    
    -- Проверяем, какие сущности исчезли (были убиты)
    for uuid, _ in pairs(trackedEntities) do
        if not currentEntities[uuid] then
            -- Сущность исчезла - увеличиваем счетчик убитых
            killed = killed + 1
            trackedEntities[uuid] = nil  -- Удаляем из отслеживаемых
        end
    end
    
    -- Очищаем trackedEntities от сущностей, которые больше не существуют
    for uuid, _ in pairs(trackedEntities) do
        if not currentEntities[uuid] then
            trackedEntities[uuid] = nil
        end
    end
    
    return foundAny
end

registerClientTick(function()
    if player.fishHook == nil and not started then
        player.input.silentUse(0)
        started = true
    end

    local entities = world.getEntities()
    local foundTarget = false

    -- Поиск целевой entity (рыболовной)
    for index, entity in ipairs(entities) do
        if entity ~= nil then
            local entityName = entity.name
            if entityName and (string.find(entityName, "!!!") or string.find(entityName, "ǃǃǃ") or string.find(entityName, "ꜝꜝꜝ")) and player.fishHook then
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
        player.input.setSelectedSlot(FISHGROD_SLOT)
        state.tick = state.tick + 1
        if state.tick >= PRESS_DELAY then
            player.input.silentUse(FISHGROD_SLOT)
            if MODE == "OneShot" then
                player.input.silentUse(ABILITY_SLOT)
                abilities = abilities + 1
                state.phase = "releasing"
                state.tick = 0
            else
                caught = caught + 1
                state.phase = "pressed"
                state.tick = 0
            end
        end
    elseif state.phase == "pressed" then
        state.tick = state.tick + 1
        if state.tick >= ENTITY_SPAWN_DELAY then
            state.phase = "ability"
            state.tick = 0
        end
    elseif state.phase == "ability" then
        state.tick = state.tick + 1
        
        -- Задержка перед проверкой сущности
        if state.tick <= ENTITY_CHECK_DELAY then
            return
        end
        
        -- Проверяем наличие сущности с "Lv" поблизости
        local hasLvEntity = hasTargetEntityNearby()
        
        if hasLvEntity then
            player.input.setSelectedSlot(ABILITY_SLOT)
            -- Вычисляем тики после задержки
            local ticksAfterDelay = state.tick - ENTITY_CHECK_DELAY
            
            -- Первая проверка после задержки - используем сразу
            if ticksAfterDelay == 1 then
                player.input.silentUse(ABILITY_SLOT)
                abilities = abilities + 1
                player.addMessage(PREFIX .. " §cUsed ability immediately - §3Sea creature §centity nearby")
                state.tick = ENTITY_CHECK_DELAY + 2
            else
                if ticksAfterDelay >= ABILITY_DELAY then
                    player.input.silentUse(ABILITY_SLOT)
                    abilities = abilities + 1
                    player.addMessage(PREFIX .. " §cUsed ability after delay - §3Sea creature §centity nearby")
                    state.tick =  ENTITY_CHECK_DELAY + 2
                end
            end
        else
            player.addMessage(PREFIX .. " §cNo §3Sea creature §centity nearby, skipping damage ability")
            player.input.setSelectedSlot(FISHGROD_SLOT)
            state.phase = "releasing"
            state.tick = 0
        end
    elseif state.phase == "releasing" then
        state.tick = state.tick + 1
        if state.tick >= RELEASE_DELAY then
            player.input.silentUse(FISHGROD_SLOT)
            state.phase = "idle"
            state.targetEntity = nil
            state.tick = 0
        end
    end
end)
