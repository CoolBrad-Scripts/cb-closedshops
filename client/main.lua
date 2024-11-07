ClosedShopPeds = {}
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
                local price = lib.inputDialog('Add Stock', {
                    {type = 'number', label = 'Price', description = 'Enter the Price', required = true, min = 1, max = 10000},
                })
                local addedToStock = lib.callback.await('cb-closedshops:server:AddStock', false, item, amount[1], price[1])
                if addedToStock then
                    Notify("Success", "You have added " .. amount[1] .. " " .. GetItemLabel(item) .. " to the shop!", "success")
                else
                    Notify("Error", "Failed to add " .. amount[1] .. " " .. GetItemLabel(item) .. " to the shop! Move closer and try again!", "error")
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
                    -- Call the server-side removal function
                    local removedFromStock = lib.callback.await('cb-closedshops:server:RemoveStock', false, v.item, amount[1])
                    
                    -- Handle the result of the stock removal
                    if removedFromStock then
                        Notify("Success", "You have removed " .. amount[1] .. " " .. GetItemLabel(v.item) .. " from the shop!", "success")
                    else
                        Notify("Error", "Failed to remove " .. amount[1] .. " " .. GetItemLabel(v.item) .. " from the shop!", "error")
                    end
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
            title = "Add Stock",
            description = "Add items to the shop",
            icon = "fa-solid fa-boxes-stacked",
            iconColor = "green",
            arrow = true,
            onSelect = function()
                AddStockMenu(job)
            end
        },
        {
            title = "Remove Stock",
            description = "Remove items from the shop",
            icon = "fa-solid fa-boxes-stacked",
            iconColor = "red",
            arrow = true,
            onSelect = function()
                RemoveStockMenu(job)
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
            local closedShopPed = CreatePed(5, closedShopModel, coords.x, coords.y, coords.z, coords.w, true, true)
            
            if DoesEntityExist(closedShopPed) then
                FreezeEntityPosition(closedShopPed, true)
                SetEntityInvincible(closedShopPed, true)
                Wait(100)
                TaskStartScenarioInPlace(closedShopPed, "WORLD_HUMAN_CLIPBOARD", 0, true)
                if not ClosedShopPeds[job] then
                    ClosedShopPeds[job] = {}
                end
                table.insert(ClosedShopPeds[job], closedShopPed)
                if Config.Target == "ox" then
                    exports.ox_target:addLocalEntity(closedShopPed, {
                        {
                            label = shopData.label,
                            icon = "fa-solid fa-shopping-cart",
                            distance = shopData.targetDistance,
                            onSelect = function()
                                exports.ox_inventory:openInventory('shop', { type = job, id = 1 })
                            end,
                        },
                        {
                            label = "Manage Shop",
                            icon = "fa-solid fa-shopping-cart",
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
                    exports['qb-target']:AddTargetEntity(closedShopPed, {
                        options = {
                            {
                                label = shopData.label,
                                icon = "fa-solid fa-shopping-cart",
                                action = function()
                                    exports.ox_inventory:openInventory('shop', { type = job, id = 1 })
                                end,
                            },
                            {
                                label = "Manage Shop",
                                icon = "fa-solid fa-shopping-cart",
                                action = function()
                                    OpenShopMenu(job)
                                end,
                                canInteract = function()
                                    local PlayerData = GetPlayerData()
                                    local playerJob = PlayerData.job.name
                                    return (ClosedShopPeds[playerJob] ~= nil) and (playerJob == job)
                                end
                            },
                        },
                        distance = shopData.targetDistance,
                    })
                end
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

RegisterNetEvent('cb-closedshops:client:SpawnClosedShopPed')
AddEventHandler('cb-closedshops:client:SpawnClosedShopPed', function(job)
    spawnClosedShopPedForPlayer(job)
end)

RegisterNetEvent('cb-closedshops:client:DeleteClosedShopPed')
AddEventHandler('cb-closedshops:client:DeleteClosedShopPed', function(job)
    if ClosedShopPeds[job] then
        for _, ped in ipairs(ClosedShopPeds[job]) do
            if DoesEntityExist(ped) then
                TriggerServerEvent('cb-closedshops:server:DeletePed', ped)
            end
        end
        ClosedShopPeds[job] = nil -- Clear the table for this job
    end
end)

RegisterNetEvent('cb-closedshops:client:DeletePed', function(ped)
    if DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
end)