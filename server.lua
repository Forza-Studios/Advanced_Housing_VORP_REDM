local AllowedSteam = {
    ["steam:110000158767928"] = true,
    ["steam:11000016de0b0ff"] = true
}

-- Helper function to resolve player creator / character owner info
local function GetPlayerOwnerInfo(src)
    local name = nil
    local steam = nil
    local isAdmin = false

    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(id, 1, 6) == "steam:" then
            steam = id
            if AllowedSteam[id] then
                isAdmin = true
            end
        end
    end

    if GetResourceState("vorp_core") == "started" then
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if ok and core and core.getUser then
            local user = core.getUser(src)
            if user then
                local character = user.getUsedCharacter
                if character then
                    local firstname = character.firstname or ""
                    local lastname = character.lastname or ""
                    local fullName = (firstname .. " " .. lastname):gsub("^%s*(.-)%s*$", "%1")
                    if fullName ~= "" then
                        name = fullName
                    end
                end
            end
        end
    end

    if not name then
        name = steam or GetPlayerName(src) or "Unknown Creator"
    end

    return {
        name = name,
        steam = steam,
        isAdmin = isAdmin
    }
end

local function GetPlayerOwnerId(src)
    local info = GetPlayerOwnerInfo(src)
    return info.name
end

-- ===== SQL Auto-Executor & Schema Migration =====
CreateThread(function()
    while GetResourceState("oxmysql") ~= "started" do
        Wait(100)
    end
    Wait(500)

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `houses` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(128) NOT NULL,
            `location` VARCHAR(128) DEFAULT 'Valentine',
            `price` INT DEFAULT 500,
            `owner` VARCHAR(128) DEFAULT NULL,
            `status` VARCHAR(32) DEFAULT 'owned',
            `locked` TINYINT(1) DEFAULT 1,
            `doorHash` VARCHAR(64) NOT NULL,
            `modelHash` VARCHAR(64) DEFAULT NULL,
            `modelName` VARCHAR(128) DEFAULT NULL,
            `x` FLOAT NOT NULL,
            `y` FLOAT NOT NULL,
            `z` FLOAT NOT NULL,
            `heading` FLOAT DEFAULT 0.0,
            `blipSprite` BIGINT DEFAULT 1586273744,
            `blipLabel` VARCHAR(128) DEFAULT NULL,
            `doors` LONGTEXT DEFAULT NULL,
            `stashX` FLOAT DEFAULT NULL,
            `stashY` FLOAT DEFAULT NULL,
            `stashZ` FLOAT DEFAULT NULL,
            `stashLimit` INT DEFAULT 100,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function(result)
        print("^2[coi_hm]^7 SQL table `houses` initialized successfully.")
        -- Migration check for existing table without locked, blipSprite, blipLabel, doors, stash columns
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `locked` TINYINT(1) DEFAULT 1;
        ]], {}, function() end)
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `blipSprite` BIGINT DEFAULT 1586273744;
        ]], {}, function() end)
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `blipLabel` VARCHAR(128) DEFAULT NULL;
        ]], {}, function() end)
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `doors` LONGTEXT DEFAULT NULL;
        ]], {}, function() end)
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `stashX` FLOAT DEFAULT NULL;
        ]], {}, function() end)
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `stashY` FLOAT DEFAULT NULL;
        ]], {}, function() end)
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `stashZ` FLOAT DEFAULT NULL;
        ]], {}, function() end)
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `stashLimit` INT DEFAULT 100;
        ]], {}, function()
            -- Auto-migrate existing single-door records to doors JSON array
            MySQL.query("SELECT id, doorHash, modelHash, modelName, x, y, z, heading, doors FROM houses", {}, function(rows)
                if rows then
                    for _, row in ipairs(rows) do
                        if not row.doors or row.doors == "" or row.doors == "[]" or row.doors == "null" then
                            local initDoor = {
                                doorHash = tostring(row.doorHash),
                                modelHash = tostring(row.modelHash or ""),
                                modelName = tostring(row.modelName or ""),
                                x = tonumber(row.x) or 0.0,
                                y = tonumber(row.y) or 0.0,
                                z = tonumber(row.z) or 0.0,
                                heading = tonumber(row.heading) or 0.0
                            }
                            local doorsJson = json.encode({ initDoor })
                            MySQL.query("UPDATE houses SET doors = ? WHERE id = ?", { doorsJson, row.id }, function() end)
                        end
                    end
                end
            end)
        end)
    end)
end)

-- Check permissions to open menu
RegisterNetEvent("coi_hm:requestOpen", function()
    local src = source

    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if AllowedSteam[id] then
            TriggerClientEvent("coi_hm:open", src)
            return
        end
    end

    TriggerClientEvent("ox_lib:notify", src, {
        title = "Housing Creator",
        description = "Access denied.",
        type = "error"
    })
end)

-- Helper to format house doors array for client sync
local function FormatHouseForClient(h)
    local doors = {}
    if h.doors and h.doors ~= "" then
        if type(h.doors) == "string" then
            local ok, parsed = pcall(json.decode, h.doors)
            if ok and type(parsed) == "table" then
                doors = parsed
            end
        elseif type(h.doors) == "table" then
            doors = h.doors
        end
    end
    if #doors == 0 then
        table.insert(doors, {
            doorHash = tostring(h.doorHash),
            modelHash = tostring(h.modelHash or ""),
            modelName = tostring(h.modelName or ""),
            x = tonumber(h.x) or 0.0,
            y = tonumber(h.y) or 0.0,
            z = tonumber(h.z) or 0.0,
            heading = tonumber(h.heading) or 0.0
        })
    end
    h.doors = doors
    return h
end

-- Fetch houses from DB and sync to client with player owner identity
local function FetchAndSendHouses(target)
    MySQL.query("SELECT * FROM houses ORDER BY id DESC", {}, function(result)
        local rawHouses = result or {}
        local houses = {}
        for _, h in ipairs(rawHouses) do
            table.insert(houses, FormatHouseForClient(h))
        end

        if target == -1 or not target then
            for _, srcStr in ipairs(GetPlayers()) do
                local pSrc = tonumber(srcStr)
                if pSrc then
                    local myInfo = GetPlayerOwnerInfo(pSrc)
                    TriggerClientEvent("coi_hm:setHouses", pSrc, houses, myInfo)
                end
            end
        else
            local myInfo = GetPlayerOwnerInfo(target)
            TriggerClientEvent("coi_hm:setHouses", target, houses, myInfo)
        end
    end)
end

RegisterNetEvent("coi_hm:requestHouses", function()
    local src = source
    FetchAndSendHouses(src)
end)

-- Create / Save House to DB
RegisterNetEvent("coi_hm:createHouse", function(data)
    local src = source
    if not data or not data.doorHash then return end

    local creatorOwner = GetPlayerOwnerId(src)
    local name = (data.name and data.name ~= "") and data.name or ("House #" .. tostring(data.doorHash))
    local location = (data.location and data.location ~= "") and data.location or "Valentine"
    local price = tonumber(data.price) or 500
    local isForSale = (data.owner == "For Sale" or data.status == "available")
    local owner = isForSale and "For Sale" or ((data.owner and data.owner ~= "") and data.owner or creatorOwner)
    local status = isForSale and "available" or "owned"
    local locked = (data.locked ~= nil) and (data.locked and 1 or 0) or 1 -- default locked = true (1)
    local doorHash = tostring(data.doorHash)
    local modelHash = tostring(data.modelHash or data.model or "")
    local modelName = tostring(data.modelName or "")
    local x = tonumber(data.x) or 0.0
    local y = tonumber(data.y) or 0.0
    local z = tonumber(data.z) or 0.0
    local heading = tonumber(data.heading) or 0.0
    local blipSprite = tonumber(data.blipSprite) or 1586273744
    local defaultLabel = isForSale and ("House For Sale ($" .. price .. ")") or (owner .. "'s House")
    local blipLabel = (data.blipLabel and data.blipLabel ~= "") and data.blipLabel or defaultLabel
    local stashLimit = tonumber(data.stashLimit) or 100

    local initDoors = {
        {
            doorHash = doorHash,
            modelHash = modelHash,
            modelName = modelName,
            x = x,
            y = y,
            z = z,
            heading = heading
        }
    }
    local doorsJson = json.encode(initDoors)

    MySQL.insert([[
        INSERT INTO houses (name, location, price, owner, status, locked, doorHash, modelHash, modelName, x, y, z, heading, blipSprite, blipLabel, doors, stashLimit)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        name, location, price, owner, status, locked, doorHash, modelHash, modelName, x, y, z, heading, blipSprite, blipLabel, doorsJson, stashLimit
    }, function(insertId)
        if insertId then
            print(("^2[coi_hm]^7 Created new house #%s (Owner: '%s', Status: '%s', Price: $%s, Stash: %skg)."):format(insertId, owner, status, price, stashLimit))
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = ("House saved! Owner: %s (Stash: %skg)"):format(owner, stashLimit),
                type = "success"
            })
            FetchAndSendHouses(-1)
        end
    end)
end)

-- Delete House from DB
RegisterNetEvent("coi_hm:deleteHouse", function(houseId)
    local src = source
    houseId = tonumber(houseId)
    if not houseId then return end

    MySQL.query("DELETE FROM houses WHERE id = ?", { houseId }, function(result)
        TriggerClientEvent("ox_lib:notify", src, {
            title = "Housing Manager",
            description = "House #" .. houseId .. " deleted.",
            type = "info"
        })
        FetchAndSendHouses(-1)
    end)
end)

-- Update House in DB
RegisterNetEvent("coi_hm:updateHouse", function(data)
    local src = source
    if not data or not data.id then return end

    local houseId = tonumber(data.id)
    local name = (data.name and data.name ~= "") and data.name or ("House #" .. houseId)
    local location = (data.location and data.location ~= "") and data.location or "Valentine"
    local price = tonumber(data.price) or 500
    local ownerInput = (data.owner and data.owner ~= "") and data.owner or "Unowned"
    local isForSale = (ownerInput == "For Sale" or data.status == "available")
    local owner = isForSale and "For Sale" or ownerInput
    local status = isForSale and "available" or ((owner ~= "Unowned" and owner ~= "") and "owned" or "available")
    local locked = (data.locked == 1 or data.locked == true or data.locked == "1") and 1 or 0
    local blipSprite = tonumber(data.blipSprite) or 1586273744
    local defaultLabel = isForSale and ("House For Sale ($" .. price .. ")") or ((owner ~= "Unowned" and owner ~= "") and (owner .. "'s House") or "House")
    local blipLabel = (data.blipLabel and data.blipLabel ~= "") and data.blipLabel or defaultLabel
    local stashLimit = tonumber(data.stashLimit) or 100

    MySQL.query([[
        UPDATE houses
        SET name = ?, location = ?, price = ?, owner = ?, status = ?, locked = ?, blipSprite = ?, blipLabel = ?, stashLimit = ?
        WHERE id = ?
    ]], {
        name, location, price, owner, status, locked, blipSprite, blipLabel, stashLimit, houseId
    }, function(result)
        print(("^2[coi_hm]^7 Updated house #%s (Owner: %s, Status: %s, StashLimit: %skg)."):format(houseId, owner, status, stashLimit))
        TriggerClientEvent("ox_lib:notify", src, {
            title = "Housing Manager",
            description = ("House #%s updated successfully!"):format(houseId),
            type = "success"
        })
        FetchAndSendHouses(-1)
    end)
end)

-- Buy House with Inventory/Character Cash (VORP Core)
RegisterNetEvent("coi_hm:buyHouse", function(houseId)
    local src = source
    houseId = tonumber(houseId)
    if not houseId then return end

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]

        local isForSale = (house.owner == "For Sale" or house.status == "available")
        if not isForSale then
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = "This house is not for sale.",
                type = "error"
            })
            return
        end

        local price = tonumber(house.price) or 500
        local buyerName = GetPlayerOwnerId(src)

        -- Check player money via VORP Core
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if ok and core and core.getUser then
            local user = core.getUser(src)
            if user then
                local character = user.getUsedCharacter
                if character then
                    local currentMoney = tonumber(character.money) or 0
                    if currentMoney < price then
                        TriggerClientEvent("ox_lib:notify", src, {
                            title = "Housing Manager",
                            description = ("Insufficient cash! Required: $%s (You have: $%s)"):format(price, currentMoney),
                            type = "error"
                        })
                        return
                    end

                    -- Deduct cash from player inventory (0 = cash currency)
                    character.removeCurrency(0, price)
                end
            end
        end

        -- Update DB: Transfer ownership to buyer
        local newBlipLabel = buyerName .. "'s House"
        MySQL.query([[
            UPDATE houses
            SET owner = ?, status = 'owned', locked = 1, blipLabel = ?
            WHERE id = ?
        ]], {
            buyerName, newBlipLabel, houseId
        }, function()
            print(("^2[coi_hm]^7 Player '%s' bought house #%s ('%s') for $%s."):format(buyerName, houseId, house.name, price))
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = ("Congratulations! You purchased '%s' for $%s!"):format(house.name, price),
                type = "success"
            })
            FetchAndSendHouses(-1)
        end)
    end)
end)

-- Owner / Admin Toggle Door Lock Event
RegisterNetEvent("coi_hm:toggleDoorLock", function(houseId)
    local src = source
    houseId = tonumber(houseId)
    if not houseId then return end

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]
        local myInfo = GetPlayerOwnerInfo(src)

        local isOwner = false
        if house.owner and myInfo.name and string.lower(tostring(house.owner)) == string.lower(tostring(myInfo.name)) then
            isOwner = true
        elseif house.owner and myInfo.steam and string.lower(tostring(house.owner)) == string.lower(tostring(myInfo.steam)) then
            isOwner = true
        end

        if not isOwner then
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = "You do not own this house.",
                type = "error"
            })
            return
        end

        local newLocked = (house.locked == 1 or house.locked == true or house.locked == "1") and 0 or 1

        MySQL.query("UPDATE houses SET locked = ? WHERE id = ?", { newLocked, houseId }, function()
            local statusStr = (newLocked == 1) and "Locked" or "Unlocked"
            print(("^2[coi_hm]^7 Owner/Admin '%s' toggled house #%s lock state to %s."):format(myInfo.name, houseId, statusStr))
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = ("Door %s!"):format(statusStr),
                type = (newLocked == 1) and "error" or "success"
            })
            FetchAndSendHouses(-1)
        end)
    end)
end)

-- Add Door to Existing House Event
RegisterNetEvent("coi_hm:addDoorToHouse", function(data)
    local src = source
    if not data or not data.houseId or not data.door then return end
    local houseId = tonumber(data.houseId)
    local newDoor = data.door
    if not newDoor or not newDoor.doorHash then return end

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]
        local doors = {}
        if house.doors and house.doors ~= "" then
            local ok, parsed = pcall(json.decode, house.doors)
            if ok and type(parsed) == "table" then doors = parsed end
        end
        if #doors == 0 then
            table.insert(doors, {
                doorHash = tostring(house.doorHash),
                modelHash = tostring(house.modelHash or ""),
                modelName = tostring(house.modelName or ""),
                x = tonumber(house.x) or 0.0,
                y = tonumber(house.y) or 0.0,
                z = tonumber(house.z) or 0.0,
                heading = tonumber(house.heading) or 0.0
            })
        end

        local newHash = tostring(newDoor.doorHash)
        for _, d in ipairs(doors) do
            if tostring(d.doorHash) == newHash then
                TriggerClientEvent("ox_lib:notify", src, {
                    title = "Housing Manager",
                    description = "This door is already attached to this house.",
                    type = "error"
                })
                return
            end
        end

        table.insert(doors, {
            doorHash = newHash,
            modelHash = tostring(newDoor.modelHash or newDoor.model or ""),
            modelName = tostring(newDoor.modelName or ""),
            x = tonumber(newDoor.x) or 0.0,
            y = tonumber(newDoor.y) or 0.0,
            z = tonumber(newDoor.z) or 0.0,
            heading = tonumber(newDoor.heading) or 0.0
        })

        local doorsJson = json.encode(doors)
        MySQL.query("UPDATE houses SET doors = ? WHERE id = ?", { doorsJson, houseId }, function()
            print(("^2[coi_hm]^7 Attached door #%s to House #%s."):format(newHash, houseId))
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = ("Door #%s attached to House #%s!"):format(newHash, houseId),
                type = "success"
            })
            FetchAndSendHouses(-1)
        end)
    end)
end)

-- Remove Door from House Event
RegisterNetEvent("coi_hm:removeDoorFromHouse", function(data)
    local src = source
    if not data or not data.houseId or not data.doorHash then return end
    local houseId = tonumber(data.houseId)
    local removeHash = tostring(data.doorHash)

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]
        local doors = {}
        if house.doors and house.doors ~= "" then
            local ok, parsed = pcall(json.decode, house.doors)
            if ok and type(parsed) == "table" then doors = parsed end
        end

        local updatedDoors = {}
        for _, d in ipairs(doors) do
            if tostring(d.doorHash) ~= removeHash then
                table.insert(updatedDoors, d)
            end
        end

        if #updatedDoors == 0 then
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = "Cannot remove the last remaining door of a house.",
                type = "error"
            })
            return
        end

        local doorsJson = json.encode(updatedDoors)
        local mainDoor = updatedDoors[1]
        MySQL.query([[
            UPDATE houses
            SET doors = ?, doorHash = ?, modelHash = ?, modelName = ?
            WHERE id = ?
        ]], {
            doorsJson, mainDoor.doorHash, mainDoor.modelHash, mainDoor.modelName, houseId
        }, function()
            print(("^2[coi_hm]^7 Detached door #%s from House #%s."):format(removeHash, houseId))
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = ("Door detached from House #%s!"):format(houseId),
                type = "info"
            })
            FetchAndSendHouses(-1)
        end)
    end)
end)

-- Set House Stash Coordinates Event
RegisterNetEvent("coi_hm:setStashCoords", function(data)
    local src = source
    if not data or not data.houseId then return end
    local houseId = tonumber(data.houseId)
    local x = tonumber(data.x)
    local y = tonumber(data.y)
    local z = tonumber(data.z)
    if not x or not y or not z then return end

    MySQL.query("UPDATE houses SET stashX = ?, stashY = ?, stashZ = ? WHERE id = ?", {
        x, y, z, houseId
    }, function()
        print(("^2[coi_hm]^7 Updated stash position for House #%s to (%s, %s, %s)."):format(houseId, x, y, z))
        TriggerClientEvent("ox_lib:notify", src, {
            title = "Housing Manager",
            description = ("Stash position set for House #%s!"):format(houseId),
            type = "success"
        })
        FetchAndSendHouses(-1)
    end)
end)

-- Open House Stash Event (vorp_inventory integration)
RegisterNetEvent("coi_hm:openStash", function(houseId)
    local src = source
    houseId = tonumber(houseId)
    if not houseId then return end

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]
        local myInfo = GetPlayerOwnerInfo(src)

        local isOwner = false
        if house.owner and myInfo.name and string.lower(tostring(house.owner)) == string.lower(tostring(myInfo.name)) then
            isOwner = true
        elseif house.owner and myInfo.steam and string.lower(tostring(house.owner)) == string.lower(tostring(myInfo.steam)) then
            isOwner = true
        elseif myInfo.isAdmin then
            isOwner = true
        end

        local isLocked = (house.locked == 1 or house.locked == true or house.locked == "1")
        if isLocked and not isOwner then
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = "This house is locked.",
                type = "error"
            })
            return
        end

        local inventoryId = "house_stash_" .. tostring(houseId)
        local stashLimit = tonumber(house.stashLimit) or 100

        if GetResourceState("vorp_inventory") == "started" and exports.vorp_inventory then
            if not exports.vorp_inventory:isCustomInventoryRegistered(inventoryId) then
                exports.vorp_inventory:registerInventory({
                    id = inventoryId,
                    name = (house.name or ("House #" .. houseId)) .. " Storage",
                    limit = stashLimit,
                    acceptWeapons = true,
                    shared = true,
                    ignoreItemStackLimit = true,
                    whitelistItems = false,
                    UsePermissions = false,
                    UseBlackList = false,
                    whitelistWeapons = false
                })
            end
            exports.vorp_inventory:openInventory(src, inventoryId)
        else
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = "vorp_inventory is not running.",
                type = "error"
            })
        end
    end)
end)