local QBCore = exports['qb-core']:GetCoreObject()
local bombPlaced = {} -- This syncs the bomb locations for people that join
local bombProp = 'prop_apple_box_01' -- Bomb prop model
local activeBombObjects = {}

-- This is just a Scully_EmoteMenu thing, feel free to obviously change animation if you want squid
local DisarmEmote = {
    Label = 'Mechanic 4',
    Command = 'mechanic4',
    Animation = 'machinic_loop_mechandplayer',
    Dictionary = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
    Options = {
        Flags = {
            Loop = true,
        },
    },
}

local ArmingEmote = {
    Label = 'Mechanic 4',
    Command = 'mechanic4',
    Animation = 'machinic_loop_mechandplayer',
    Dictionary = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
    Options = {
        Flags = {
            Loop = true,
        },
    },
}

-- Event to place bomb with progress bar
RegisterNetEvent('bomb:client:PlaceBomb', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    exports['scully_emotemenu']:playEmote(ArmingEmote)

    -- Start placing bomb!
    local success = lib.progressBar({
        duration = 10000,  -- Time to place the bomb (10 seconds)
        label = 'Planting Bomb',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        }
    })

    if success then
        local bombObject = CreateObject(GetHashKey(bombProp), coords.x, coords.y, coords.z, true, true, true)
        table.insert(activeBombObjects, bombObject)

        -- Set properties for the bomb object (optional)
        PlaceObjectOnGroundProperly(bombObject)
        FreezeEntityPosition(bombObject, true)

        -- Notify the Police about the bomb placement / Currently using PS-Dispatch but should be pretty easy to add other dispatch systems
        TriggerServerEvent('bomb:server:PlaceBomb', coords)
        exports['ps-dispatch']:ied()

        -- Notify the Bomber with the command
        lib.notify({
            title = 'Bomb Placed',
            description = 'Use /detonate to trigger it remotely',
            type = 'success'
        })
        
        exports['scully_emotemenu']:cancelEmote()
    else
        lib.notify({
            title = 'Canceled',
            description = 'Bomb placement canceled.',
            type = 'error'
        })
    end
end)


-- Sync bombs from the server
RegisterNetEvent('bomb:client:SyncBombs', function(updatedBombData)
    bombPlaced = updatedBombData
end)

-- Event to detonate bomb client-side (triggered from server)
RegisterNetEvent('bomb:client:DetonateBomb', function(coords)
    AddExplosion(coords.x, coords.y, coords.z, 2, 10.0, true, false, 2.0)
end)


-- This command is to bring up the ox_lib menu that can detonate the bomb
RegisterCommand('detonate', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local playerData = QBCore.Functions.GetPlayerData()

    local hasDetonator = false
    for _, item in pairs(playerData.items) do
        if item.name == 'detonator' then
            hasDetonator = true
            break
        end
    end

    if hasDetonator then
        local closestBomb = nil
        local closestDistance = 200.0

        -- Find the closest bomb
        for index, bombData in pairs(bombPlaced) do
            local distance = #(playerCoords - vector3(bombData.coords.x, bombData.coords.y, bombData.coords.z))
            if distance < closestDistance then
                closestDistance = distance
                closestBomb = index
            end
        end

        if closestBomb then
            -- Register the menu
				lib.registerContext({
    id = 'detonate_menu',
    title = 'Detonate Menu',
    options = {
        {
            title = 'Detonate Bomb',
            description = 'Detonate the closest bomb.',
            onSelect = function()
                -- Trigger to make things go boom!
                TriggerServerEvent('bomb:server:DetonateBomb', closestBomb)
            end
        },
        {
            title = 'Cancel',
            description = 'Cancel the detonation.',
            onSelect = function()
                lib.notify({
                    title = 'Canceled',
                    description = 'Bomb detonation canceled.',
                    type = 'error'
                })
            end
        }
    }
})
            -- Show the menu
            lib.showContext('detonate_menu')
        else
            lib.notify({
                title = 'No Bombs Nearby',
                description = 'No bombs are within range to detonate.',
                type = 'error'
            })
        end
    else
        lib.notify({
            title = 'Missing Item',
            description = 'You need a detonator to use this command.',
            type = 'error'
        })
    end
end)


-- Event that will let PD dorks to disarm the bomb. Might improve the skill check to a mini-game if i decided to make variant of bombs i.e deadman switch, phone detonated bomb etc
RegisterNetEvent('bomb:client:DisarmBomb', function(bombIndex)
    local PlayerData = QBCore.Functions.GetPlayerData()
    exports['scully_emotemenu']:playEmote(DisarmEmote)

    if PlayerData.job.name == "police" then
        -- Trigger the ps-scrambler mini-game
        exports['ps-ui']:Scrambler(function(success)
            if success then
                -- If the mini-game is successful, disarm the bomb
                if bombObject and DoesEntityExist(bombObject) then
                    DeleteObject(bombObject)  -- Delete the bomb prop
                    bombObject = nil  -- Optionally set to nil to avoid referencing a deleted object
                end

                -- Remove from the activeBombObjects table
                if bombIndex and activeBombObjects[bombIndex] then
                    table.remove(activeBombObjects, bombIndex)  -- Remove from the activeBombObjects table
                end

                -- Notify the server about bomb disarm
                TriggerServerEvent('bomb:server:DisarmBomb', bombIndex)
                exports['scully_emotemenu']:cancelEmote()

                -- Notify the player of successful disarm
                lib.notify({
                    title = 'Bomb Disarmed',
                    description = 'You successfully disarmed the bomb.',
                    type = 'success'
                })
            else
                -- If the mini-game fails, trigger an explosion locally
                local bomb = bombPlaced[bombIndex]
                if bomb then
                    AddExplosion(bomb.coords.x, bomb.coords.y, bomb.coords.z, 2, 10.0, true, false, 2.0)
                end
                exports['scully_emotemenu']:cancelEmote()

                -- Notify the player of the failure
                lib.notify({
                    title = 'Disarm Failed',
                    description = 'The bomb exploded!',
                    type = 'error'
                })
            end
        end, 'alphanumeric', 30, mirrored)  -- 
    end
end)



-- Event triggered when the player uses the disarm tool
RegisterNetEvent('bomb:client:useDisarmTool', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Check if the player is near any bombs
    for index, bombData in pairs(bombPlaced) do
        if #(playerCoords - bombData.coords) < 2.0 then
            -- If the player is near a bomb, trigger the disarm process
            TriggerEvent('bomb:client:DisarmBomb', index)
            break
        else
            -- Notify player if no bomb is nearby
            lib.notify({
                title = 'No Bomb Found',
                description = 'You are not near any bomb to disarm.',
                type = 'error'
            })
        end
    end
end)


-- RECOMMEND LEAVING THIS OFF IF YOU HAVE YOUR DISARMING TOOL IN ITEMS.LUA
-- Command for police to disarm the bomb
--[[RegisterCommand('disarmbomb', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Check if the player is near any bombs
    for index, bombData in pairs(bombPlaced) do
        if #(playerCoords - bombData.coords) < 2.0 then
            TriggerEvent('bomb:client:DisarmBomb', index)
            break
        end
    end
end)]]--