ClosedShopPeds = {}

lib.callback.register('cb-closedshops:client:SetPrice', function()
    local price = lib.inputDialog('Add Stock', {
        {type = 'number', label = 'Price', description = 'Enter the price of the item', required = true, min = 1, max = 999999},
    })
    return price[1]
end)

function ChangePriceMenu(job)
    local menuOptions = {}

    -- Find the allowed items based on the player's job
    local allowedItems = {}
    for _, shop in pairs(Config.ClosedShops) do
        if shop.job == job then
            allowedItems = shop.allowedItems
            break
        end
    end

    local stockItems = lib.callback.await('cb-closedshops:server:GetStockItems', false, job)
    if not stockItems or #stockItems == 0 then
        Notify("No Buy Orders", "You have no existing Buy Orders!", "error")
        return
    end
    for k, v in ipairs(stockItems) do
        table.insert(menuOptions, {
            title = GetItemLabel(v.item),  -- Use the item label
            description = "Current Price: $" .. v.price,
            icon = GetItemImage(v.item),  -- Assume GetItemImage returns a valid icon
            arrow = true,
            disabled = v.amount <= 0,  -- Disable if no stock
            onSelect = function()               
                -- Display input dialog for removing stock
                local price = lib.inputDialog('Change Price', {
                    {type = 'number', label = 'Price', description = 'How much are you willing to pay for each item?', required = true, min = 1, max = 999999},
                })
                
                if price then
                    TriggerServerEvent('cb-closedshops:server:ChangePrice', v.item, price)
                end
            end
        })
    end
    lib.registerContext({
        id = 'AddStockMenu',
        title = "Add Stock",
        options = menuOptions
    })
    lib.showContext('AddStockMenu')
end

function AddStockMenu(job)
    local menuOptions = {}

    -- Find the allowed items based on the player's job
    local allowedItems = {}
    for _, shop in pairs(Config.ClosedShops) do
        if shop.job == job then
            allowedItems = shop.allowedItems
            break
        end
    end

    for _, item in ipairs(allowedItems) do
        table.insert(menuOptions, {
            title = GetItemLabel(item),
            description = "Add " .. GetItemLabel(item) .. " to the shop",
            icon = GetItemImage(item),
            arrow = true,
            disabled = not HasItemClient(item, 1),
            onSelect = function()
                local maxAmount = 1000
                if UsingOxInventory then
                    maxAmount = exports.ox_inventory:GetItemCount(item)
                end
                local amount = lib.inputDialog('Add Stock', {
                    {type = 'number', label = 'Amount', description = 'Enter the amount of items to add', required = true, min = 1, max = maxAmount},
                })
                TriggerServerEvent('cb-closedshops:server:IncreaseBuyOrder', item, amount[1])
            end
        })
    end

    lib.registerContext({
        id = 'AddStockMenu',
        title = "Add Stock",
        options = menuOptions
    })
    lib.showContext('AddStockMenu')
end

function OpenClosedShop(job)
    local menuOptions = {}
    local shopItems = lib.callback.await('cb-closedshops:server:GetShopItems', false, job)
    for k,v in pairs(shopItems) do
        table.insert(menuOptions, {
            title = GetItemLabel(v.item),
            description = "Current Price: $" .. v.price .. "\nAmount: " .. v.amount,
            icon = GetItemImage(v.item),
            arrow = true,
            disabled = not (v.amount > 0),
            onSelect = function()
                local amount = lib.inputDialog('Current Price: $'..v.price, {
                    {type = 'number', label = 'Amount', description = 'Enter the amount you are willing to buy!', required = true, min = 1, max = v.amount},
                })
                TriggerServerEvent('cb-closedshops:server:PurchaseItem', job, v.item, amount[1])
            end
        })
    end

    lib.registerContext({
        id = 'ClosedShopMenu',
        title = "Closed Shop",
        options = menuOptions
    })
    lib.showContext('ClosedShopMenu')
end

function RemoveStockMenu(job)
    local menuOptions = {}
    
    -- Fetch stock items from the server
    local stockItems = lib.callback.await('cb-closedshops:server:GetStockItems', false, job)
    
    -- If no stock items, exit the function
    if not stockItems or #stockItems == 0 then
        Notify("Error", "No items found in stock!", "error")
        return
    end
    
    -- Iterate over the stock items and build menu options
    for k, v in ipairs(stockItems) do
        table.insert(menuOptions, {
            title = GetItemLabel(v.item),  -- Use the item label
            description = "Remove " .. GetItemLabel(v.item) .. " from the shop",
            icon = GetItemImage(v.item),  -- Assume GetItemImage returns a valid icon
            arrow = true,
            disabled = v.amount <= 0,  -- Disable if no stock
            onSelect = function()
                local maxAmount = v.amount
                
                -- Display input dialog for removing stock
                local amount = lib.inputDialog('Remove Stock', {
                    {type = 'number', label = 'Amount', description = 'Enter the amount of items to remove', required = true, min = 1, max = maxAmount},
                })
                
                if amount then
                    TriggerServerEvent('cb-closedshops:server:DecreaseBuyOrder', v.item, amount[1])
                end
            end
        })
    end
    
    -- Register and display the menu
    lib.registerContext({
        id = 'RemoveStockMenu',
        title = GetPlayerJobLabel() .. " - Remove Items",
        options = menuOptions
    })
    
    -- Show the menu
    lib.showContext('RemoveStockMenu')
end

function OpenShopMenu(job)
    local menuOptions = {
        {
            title = "Increase Buy Order",
            description = "Increase the number of items you are willing to purchase",
            icon = "fa-solid fa-boxes-stacked",
            iconColor = "green",
            arrow = true,
            onSelect = function()
                AddStockMenu(job)
            end
        },
        {
            title = "Decrease Buy Order",
            description = "Decrease the number of items you are willing to purchase",
            icon = "fa-solid fa-boxes-stacked",
            iconColor = "red",
            arrow = true,
            onSelect = function()
                RemoveStockMenu(job)
            end
        },
        {
            title = "Change Price",
            description = "Change the price of an existing Buy Order",
            icon = "fa-solid fa-money-bill",
            iconColor = "orange",
            arrow = true,
            onSelect = function()
                ChangePriceMenu(job)
            end
        }
    }

    lib.registerContext({
        id = 'OpenShopMenu',
        title = GetPlayerJobLabel(),
        options = menuOptions
    })
    lib.showContext('OpenShopMenu')
end

local function spawnClosedShopPedForPlayer(job)
    local closedShopModel = `a_m_y_business_02`
    -- Load the model
    RequestModel(closedShopModel)
    local tries = 0
    while not HasModelLoaded(closedShopModel) and tries < 10 do
        Wait(500)
        tries = tries + 1
    end

    if HasModelLoaded(closedShopModel) then
        -- Find the shop configuration for the given job
        local shopData = nil
        for _, shop in pairs(Config.ClosedShops) do
            if job == shop.job then
                shopData = shop
                break
            end
        end

        if shopData and shopData.coords then
            local coords = shopData.coords
            local closedShopPed = CreatePed(5, closedShopModel, coords.x, coords.y, coords.z, coords.w, false, true)
            if DoesEntityExist(closedShopPed) then
                FreezeEntityPosition(closedShopPed, true)
                SetEntityInvincible(closedShopPed, true)
                Wait(100)
                SetBlockingOfNonTemporaryEvents(closedShopPed, true)
                SetPedCanPlayAmbientAnims(closedShopPed, true)
                TaskStartScenarioInPlace(closedShopPed, "WORLD_HUMAN_CLIPBOARD", 0, true)
                if not ClosedShopPeds[job] then
                    ClosedShopPeds[job] = {}
                end
                table.insert(ClosedShopPeds[job], closedShopPed)

                exports.ox_target:addLocalEntity(closedShopPed, {
                    {
                        label = shopData.label,
                        icon = "fa-solid fa-shopping-cart",
                        distance = shopData.targetDistance,
                        onSelect = function()
                            OpenClosedShop(job)
                        end,
                    },
                    {
                        label = "Manage Shop",
                        icon = "fa-solid fa-briefcase",
                        distance = shopData.targetDistance,
                        onSelect = function()
                            OpenShopMenu(job)
                        end,
                        canInteract = function()
                            local PlayerData = GetPlayerData()
                            local playerJob = PlayerData.job.name
                            return (ClosedShopPeds[playerJob] ~= nil) and (playerJob == job)
                        end
                    },
                })
            else
                lib.print.error("Failed to create the shop ped at " .. tostring(coords))
            end
        end
        SetModelAsNoLongerNeeded(closedShopModel)
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('cb-closedshops:server:OnLoadSpawnShopPeds')
end)

RegisterNetEvent('cb-closedshops:client:Notify', function(label, message, type)
    Notify(label, message, type)
end)

RegisterNetEvent('cb-closedshops:client:DeleteShopPeds', function(job)
    if ClosedShopPeds[job] then
        for _, ped in ipairs(ClosedShopPeds[job]) do
            if DoesEntityExist(ped) then
                DeleteEntity(ped)
            end
        end
        ClosedShopPeds[job] = nil -- Clear the table for this job
    end
end)

RegisterNetEvent('cb-closedshops:client:SpawnClosedShopPed')
AddEventHandler('cb-closedshops:client:SpawnClosedShopPed', function(job)
    spawnClosedShopPedForPlayer(job)
end)

RegisterNetEvent('cb-closedshops:client:DeletePed', function(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
end)