SpawnedShopPeds = {}

AddEventHandler('QBCore:Server:SetDuty', function(source, onDuty)
    local src = source
    local Player = GetPlayer(src)
    local job = Player.PlayerData.job.name
    -- Loop through all closed shops in the config
    for _, shop in pairs(Config.ClosedShops) do
        if job == shop.job then
            if GetDutyCount(job) == 0 then
                -- Spawn the shop ped if no one is on duty
                TriggerClientEvent('cb-closedshops:client:SpawnClosedShopPed', -1, job)
                SpawnedShopPeds[job] = true
            else
                -- Delete the shop ped if someone is on duty
                if (SpawnedShopPeds[job] ~= nil) then
                    TriggerClientEvent('cb-closedshops:client:DeleteClosedShopPed', -1, job)
                    SpawnedShopPeds[job] = false
                end
            end
        end
    end
end)

RegisterNetEvent('cb-closedshops:server:OnLoadSpawnShopPeds')
AddEventHandler('cb-closedshops:server:OnLoadSpawnShopPeds', function()
    for _, shop in pairs(Config.ClosedShops) do
        local onDuty = GetDutyCount(shop.job)
        if onDuty <= 0 then
            TriggerClientEvent('cb-closedshops:client:SpawnClosedShopPed', -1, shop.job)
            SpawnedShopPeds[shop.job] = true
            UpdateClosedShop(shop.job)
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    -- Loop through each closed shop in the config
    for _, shop in pairs(Config.ClosedShops) do
        local onDuty = GetDutyCount(shop.job)
        if onDuty == nil then onDuty = 0 end        
        -- If no one is on duty for the job related to this shop, spawn the ped
        if onDuty == 0 then
            Citizen.Wait(1500)
            TriggerClientEvent('cb-closedshops:client:SpawnClosedShopPed', -1, shop.job)
            SpawnedShopPeds[shop.job] = true
        end
    end

    -- Call any other necessary update functions after spawning the peds
    for _, shop in pairs(Config.ClosedShops) do
        UpdateClosedShop(shop.job)
    end
end)

CreateThread(function()
    if UsingOxInventory then
        local hookId = exports.ox_inventory:registerHook('buyItem', function(payload)
            for _, shop in pairs(Config.ClosedShops) do
                if payload.shopType == shop.job then
                    local item = payload.itemName
                    local count = payload.count
                    if RemoveFromStock(item, count, shop.job) then
                        local price = payload.totalPrice
                        local Player = GetPlayer(payload.source)
                        if Player == nil then return end
                        local fullName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
                        AddMoneyToJobAccount(shop.job, payload.totalPrice, fullName)
                        return true
                    else
                        return false
                    end
                else
                    return true
                end
            end
        end, {})
    end
end)

lib.callback.register('cb-closedshops:server:GetStockItems', function(source, job)
    local src = source
    if src == nil then return false end
    local Player = GetPlayer(src)
    if Player == nil then return end

    local query = [[
        SELECT item, price, amount FROM business_stock WHERE business = ?
    ]]
    local result = SQLQuery(query, {job})
    if result and #result > 0 then
        return result
    else
        return false
    end
end)

lib.callback.register('cb-closedshops:server:hasRequiredItem', function(source, item)
    local src = source
    if src == nil then return false end
    local Player = GetPlayer(src)
    if Player == nil then return end
    if HasItem(src, item, 1) then
        return true
    else
        return false
    end
end)

lib.callback.register('cb-closedshops:server:AddStock', function(source, item, amount, price)
    local src = source
    if src == nil then return false end
    local Player = GetPlayer(src)
    if Player == nil then return end
    local job = Player.PlayerData.job.name
    local coords = GetPlayerCoords(src)
    for k, v in pairs(Config.ClosedShops) do
        if v.job == job then
            local dist = #(vector3(v.coords.x, v.coords.y, v.coords.z) - coords)
            if dist > 5.0 then
                DiscordLog(string.format("%s attempted to add stock to %s from a distance of %.0f. Possibly Cheating", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, job, dist))
                return false
            end
        end
    end
    if Player == nil then return false end

    -- Remove item from player's inventory (if applicable)
    if RemoveItem(src, item, amount) then
        -- Check if the item already exists for the given business in the database
        local checkQuery = [[
            SELECT amount FROM business_stock WHERE business = ? AND item = ?
        ]]
        local result = SQLQuery(checkQuery, {job, item})

        if result and #result > 0 then
            -- If the item exists, update the amount
            local updateQuery = [[
                UPDATE business_stock 
                SET amount = amount + ?, price = ?, updated_at = CURRENT_TIMESTAMP
                WHERE business = ? AND item = ?
            ]]
            SQLQuery(updateQuery, {amount, price, job, item})
            UpdateClosedShop(job)
        else
            -- If the item does not exist, insert a new row
            local insertQuery = [[
                INSERT INTO business_stock (business, item, amount, price, updated_at)
                VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
            ]]
            SQLQuery(insertQuery, {job, item, amount, price})
            UpdateClosedShop(job)
        end
        return true
    else
        return false
    end
end)

lib.callback.register('cb-closedshops:server:RemoveStock', function(source, item, amount)
    local src = source
    if src == nil then return false end

    local Player = GetPlayer(src)
    if Player == nil then return false end

    local job = Player.PlayerData.job.name
    local coords = GetPlayerCoords(src)
    for k, v in pairs(Config.ClosedShops) do
        if v.job == job then
            local dist = #(vector3(v.coords.x, v.coords.y, v.coords.z) - coords)
            if dist > 5.0 then
                DiscordLog(string.format("%s attempted to remove stock to %s from a distance of %.0f. Possibly Cheating", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, job, dist))
                return false
            end
        end
    end


    if UsingOxInventory then
        -- Query to get the current amount of the item in stock for the player's job/business
        local query = [[
            SELECT amount FROM business_stock WHERE business = ? AND item = ?
        ]]
        local result = SQLQuery(query, {job, item})

        if result and #result > 0 then
            local currentAmount = result[1].amount

            -- Check if there's enough stock to remove
            if currentAmount >= amount then
                -- Update the stock, reducing the item count
                local updateQuery = [[
                    UPDATE business_stock SET amount = amount - ? WHERE business = ? AND item = ?
                ]]
                local updateResult = SQLQuery(updateQuery, {amount, job, item})

                -- If update is successful, return true
                if updateResult then
                    if AddItem(source, item, amount) then
                        UpdateClosedShop(job)
                        return true
                    else
                        TriggerClientEvent('cb-closedshops:client:Notify', source, "Inventory Error", "There was an issue adding the item! Please try again!", "error")
                        return false
                    end
                else
                    return false
                end
            else
                -- Not enough stock to remove the requested amount
                TriggerClientEvent('cb-closedshops:client:Notify', source, "Not Enough Stock", "Not enough stock of " .. GetItemLabel(item) .. " to remove.", "error")
                return false
            end
        else
            -- Item not found in stock
            TriggerClientEvent('cb-closedshops:client:Notify', source, "No Stock", "You don't have any of this item in stock!", "error")
            return false
        end
    else
        return false
    end
end)

function RemoveFromStock(item, amount, job)
    if UsingOxInventory then
        -- Query to get the current amount of the item in stock
        local query = [[
            SELECT amount FROM business_stock WHERE business = ? AND item = ?
        ]]
        local result = SQLQuery(query, {job, item})

        if result and #result > 0 then
            local currentAmount = result[1].amount

            -- Check if there's enough stock to remove
            if currentAmount >= amount then
                -- Update the stock, reducing the item count
                local updateQuery = [[
                    UPDATE business_stock SET amount = amount - ? WHERE business = ? AND item = ?
                ]]
                local updateResult = SQLQuery(updateQuery, {amount, job, item})

                -- If update is successful, return true
                if updateResult then
                    return true
                else
                    -- Handle failure of stock update
                    return false
                end
            else
                -- Not enough stock to remove the requested amount
                return false
            end
        else
            -- Item not found in stock
            return false
        end
    else
        -- OxInventory is not in use, handle accordingly
        return false
    end
end

function UpdateClosedShop(job)
    if UsingOxInventory then
        -- Query to get the items and prices from the database for the specified job
        local query = [[
            SELECT item, price, amount FROM business_stock WHERE business = ?
        ]]
        local result = SQLQuery(query, {job})  -- Use the passed job to query

        -- Prepare the inventory dynamically based on the result from the database
        local inventory = {}

        if result and #result > 0 then
            for i = 1, #result do
                table.insert(inventory, {
                    name = result[i].item,
                    price = result[i].price,
                    count = result[i].amount,
                    currency = 'money'
                })
            end
        end

        -- Register the shop with the dynamic inventory
        for _, shop in pairs(Config.ClosedShops) do
            if shop.job == job then
                local uniquename = shop.job
                exports.ox_inventory:RegisterShop(uniquename, {
                    name = shop.job,
                    inventory = inventory,
                    locations = {
                        vec3(shop.coords.x, shop.coords.y, shop.coords.z)
                    }
                })
            end
        end
    end
end

RegisterNetEvent('cb-closedshops:server:DeletePed')
AddEventHandler('cb-closedshops:server:DeletePed', function(ped)
    TriggerClientEvent('cb-closedshops:client:DeletePed', -1, ped)
end)