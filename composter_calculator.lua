local sended = false
local box_of_seed_organic = 25600
local volta_fuel = 10000

local function matchComposterResource(text)
-- Удаляем все пробелы из строки перед проверкой
local cleanedText = text:gsub("%s+", "")
cleanedText = cleanedText:gsub(",", "")
local current, max = cleanedText:match("^(%d[%d,]*%.?%d*)/(%d+)k$")
return tonumber(current), tonumber(max)
end

registerClientTick(function()
local organicItem = player.inventory.getStackFromContainer(37 + 9)
local fuelItem = player.inventory.getStackFromContainer(43 + 9)

if fuelItem and organicItem and organicItem.lore and #organicItem.lore > 0 then
    local organicCurrent, organicMax = matchComposterResource(organicItem.lore[1])
    local fuelCurrent, fuelMax = matchComposterResource(fuelItem.lore[1])
    if organicCurrent and organicMax and fuelCurrent and fuelMax then
        -- Рассчитываем сколько нужно добавить
        local neededOrganic = organicMax * 1000 - organicCurrent
        local neededFuel = fuelMax * 1000 - fuelCurrent

        -- Рассчитываем количество предметов
        local boxesNeeded = math.floor(neededOrganic / box_of_seed_organic)
        local voltaNeeded = math.floor(neededFuel / volta_fuel)

        -- Проверяем, можно ли добавить еще один предмет без переполнения
        if boxesNeeded > 0 then
            local finalOrganic = organicCurrent + (boxesNeeded * box_of_seed_organic)
            if finalOrganic > (organicMax * 1000) then
                boxesNeeded = boxesNeeded - 1
                end
            end

            if voltaNeeded > 0 then
                local finalFuel = fuelCurrent + (voltaNeeded * volta_fuel)
                if finalFuel > (fuelMax * 1000) then
                    voltaNeeded = voltaNeeded - 1
                end
            end

            -- Показываем информацию
            if not sended then
                player.addMessage("§cComposter Calculator")
                player.addMessage("§aBox of Seed: §f§l" .. boxesNeeded .. "x.")
                player.addMessage("§bVolta: §f§l" .. voltaNeeded .. "x.")

                -- Рассчитываем итоговые значения после добавления
                local finalOrganic = organicCurrent + (boxesNeeded * box_of_seed_organic)
                local finalFuel = fuelCurrent + (voltaNeeded * volta_fuel)

                player.addMessage("§7(Organic: " .. finalOrganic .. "/" .. organicMax * 1000 .. ")")
                player.addMessage("§7(Fuel: " .. finalFuel .. "/" .. fuelMax * 1000 .. ")")

                sended = true
            end
        else
            sended = false
        end
    else
        sended = false
    end
end)
