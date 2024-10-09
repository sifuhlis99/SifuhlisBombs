local QBCore = exports['qb-core']:GetCoreObject()
local bombData = {} -- This initializes bombData as an empty table
local ox_lib = exports.ox_lib
local bombPlaced = {}

-- Register the bomb item as usable
QBCore.Functions.CreateUseableItem('boxbomb', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    
    -- Trigger the bomb placement event on the client
    if player then
        TriggerClientEvent('bomb:client:PlaceBomb', source)
    end
end)

QBCore.Functions.CreateUseableItem('bombdisposaltools', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    
    -- Yummy yum disarming kit
    if player then
        TriggerClientEvent('bomb:client:useDisarmTool', source)
    end
end)

-- Place that bomb, yaaaas bitch.... It's 8am... i've been up 18hrs now..
RegisterNetEvent('bomb:server:PlaceBomb', function(coords)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)

    -- Check if player has the bomb item in their inventory
    if player then
        local hasBombItem = player.Functions.GetItemByName('boxbomb')

        if hasBombItem ~= nil then
            -- Store bomb data with owner and coordinates
            table.insert(bombData, { coords = coords, owner = src })

            -- Sync bomb data to all clients
            TriggerClientEvent('bomb:client:SyncBombs', -1, bombData)

            -- Remove one bomb item from the player's inventory
            player.Functions.RemoveItem('boxbomb', 1)
        else
            -- If the player doesn't have the bomb item, notify them
            TriggerClientEvent('QBCore:Notify', src, 'You don\'t have a bomb to place!', 'error')
        end
    end
end)


-- Server side boom boom stuff
RegisterNetEvent('bomb:server:DetonateBomb', function(bombIndex)
    local bomb = bombData[bombIndex]
    if bomb then
        TriggerClientEvent('bomb:client:DetonateBomb', -1, bomb.coords)
        table.remove(bombData, bombIndex)  -- Remove the bomb after detonation
        TriggerClientEvent('bomb:client:SyncBombs', -1, bombData)  -- Sync updated bomb data
    end
end)

-- Server side no boom boom stuff
RegisterNetEvent('bomb:server:DisarmBomb', function(bombIndex)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)

    -- Validate that the player is a police officer
    if player and player.PlayerData.job.name == "police" then
        -- Remove the bomb from the data table
        table.remove(bombData, bombIndex)

        -- Sync the updated bomb data to all clients
        TriggerClientEvent('bomb:client:SyncBombs', -1, bombData)
        
    else
        -- If someone who is not a police officer attempts to disarm, give them this message
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t the training to do this!', 'error')
    end
end)

-- Function to sync bomb data to a player when they join (so they see all active bombs)
AddEventHandler('playerConnecting', function()
    local src = source
    TriggerClientEvent('bomb:client:SyncBombs', src, bombData)
end)
