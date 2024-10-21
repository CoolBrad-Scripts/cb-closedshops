CreateThread(function()
    Framework = "qb-core"
    UsingOxInventory = false
    if GetResourceState('qbx_core') == 'started' then
        Framework = "qbox"
    elseif GetResourceState('qb-core') == 'started' then
        Framework = "qb-core"
    end
    if GetResourceState('ox_inventory') == 'started' then
        UsingOxInventory = true
    end
end)

function GetPlayerData()
    if Framework == "qb-core" then
        return QBCore.Functions.GetPlayerData()
    elseif Framework == "qbox" then
        return QBX.PlayerData
    end
end

function Notify(label, message, type)
    lib.notify({
        title = label,
        description = message,
        duration = 7500,
        type = type
    })
end

function GetPlayerJob()
   return GetPlayerData().job.name
end

function GetPlayerJobLabel()
    return GetPlayerData().job.label
end

function IsOnDuty()
    return GetPlayerData().job.onduty
end

function IsPlayerBoss()
    return GetPlayerData().job.isboss
end

function OpenStash(jobName)
    if UsingOxInventory then
        TriggerServerEvent("cb-closedshops:server:RegisterStash", jobName)
    end
    -- TODO: Other Inventory Support
end

function HasItemClient(item, amount)
    if amount == nil then amount = 1 end
    local itemCount = exports.ox_inventory:GetItemCount(item)
    if not itemCount then
        return false
    elseif itemCount >= amount then
        return true
    else
        return false
    end
end

function GetPlayerOutfit(ped)
    local outfit = {
        mask = {
            drawable = GetPedDrawableVariation(ped, 1),
            texture = GetPedTextureVariation(ped, 1)
        },
        hair = {
            drawable = GetPedDrawableVariation(ped, 2),
            texture = GetPedTextureVariation(ped, 2)
        },
        torso = {
            drawable = GetPedDrawableVariation(ped, 3),
            texture = GetPedTextureVariation(ped, 3)
        },
        legs = {
            drawable = GetPedDrawableVariation(ped, 4),
            texture = GetPedTextureVariation(ped, 4)
        },
        bags = {
            drawable = GetPedDrawableVariation(ped, 5),
            texture = GetPedTextureVariation(ped, 5)
        },
        shoes = {
            drawable = GetPedDrawableVariation(ped, 6),
            texture = GetPedTextureVariation(ped, 6)
        },
        accessories = {
            drawable = GetPedDrawableVariation(ped, 7),
            texture = GetPedTextureVariation(ped, 7)
        },
        undershirts = {
            drawable = GetPedDrawableVariation(ped, 8),
            texture = GetPedTextureVariation(ped, 8)
        },
        bodyarmor = {
            drawable = GetPedDrawableVariation(ped, 9),
            texture = GetPedTextureVariation(ped, 9)
        },
        decals = {
            drawable = GetPedDrawableVariation(ped, 10),
            texture = GetPedTextureVariation(ped, 10)
        },
        tops = {
            drawable = GetPedDrawableVariation(ped, 11),
            texture = GetPedTextureVariation(ped, 11)
        },
        hats = {
            drawable = GetPedDrawableVariation(ped, 1),
            texture = GetPedTextureVariation(ped, 1)
        },
        glasses = {
            drawable = GetPedDrawableVariation(ped, 1),
            texture = GetPedTextureVariation(ped, 1)
        },
        ears = {
            drawable = GetPedDrawableVariation(ped, 1),
            texture = GetPedTextureVariation(ped, 1)
        },
        watches = {
            drawable = GetPedDrawableVariation(ped, 1),
            texture = GetPedTextureVariation(ped, 1)
        },
        bracelets = {
            drawable = GetPedDrawableVariation(ped, 1),
            texture = GetPedTextureVariation(ped, 1)
        }
    }
    return outfit
end

function GetItemLabel(item)
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:Items(item).label
    else
        return QBCore.Shared.Items[item].label
    end
end

function GetItemImage(item)
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:Items(item).client.image
    else
        return "nui://" .. Config.InventoryImage .. QBCore.Shared.Items[item].image
    end
end

RegisterNetEvent('cb-closedshops:client:NotEnoughSpace', function()
    lib.notify({
        title = "Not Enough Space",
        description = "You don't have enough space in your inventory to take more items!",
        duration = 7500,
        position = 'center-right',
        icon = 'ban',
        iconColor = '#C53030'
    })
end)