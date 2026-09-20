local AllowedSteam = {
    ["steam:110000158767928"] = true,
    ["steam:11000016de0b0ff"] = true,
    ["steam:110000171bc6281"] = true,
    ["steam:110000155d3269f"] = true,
    ["steam:11000016ead0d6b"] = true
    
}

-- Helper function to resolve player creator / character owner info from VORP Core
local function GetPlayerOwnerInfo(src)
    local name = nil
    local steam = nil
    local license = nil
    local charIdentifier = nil
    local isAdmin = false
    local playerName = GetPlayerName(src)

    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(id, 1, 6) == "steam:" then
            steam = id
            if AllowedSteam[id] then
                isAdmin = true
            end
        elseif string.sub(id, 1, 8) == "license:" then
            license = id
        end
    end

    if GetResourceState("vorp_core") == "started" then
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if ok and core and core.getUser then
            local user = core.getUser(src)
            if user then
                local character = user.getUsedCharacter
                if character then
                    charIdentifier = tostring(character.charIdentifier or character.identifier or "")
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

    if not name or name == "" then
        name = playerName or steam or "Unknown Player"
    end

    return {
        source = src,
        name = name,
        playerName = playerName,
        steam = steam,
        license = license,
        charIdentifier = (charIdentifier and charIdentifier ~= "") and tostring(charIdentifier) or nil,
        isAdmin = isAdmin
    }
end

local function GetPlayerOwnerId(src)
    local info = GetPlayerOwnerInfo(src)
    return info.name
end

-- Central Helper for Left-Side Notifications (ox_lib:notify position = "top-left")
local function SendNotify(src, payload)
    if type(payload) == "table" then
        payload.position = "top-left"
    end
    TriggerClientEvent("ox_lib:notify", src, payload)
end

-- ===== SQL Auto-Executor & Schema Migration (Normalized Architecture) =====
CreateThread(function()
    while GetResourceState("oxmysql") ~= "started" do
        Wait(100)
    end
    Wait(500)

    -- 1. Create normalized houses table with owner_charid & index
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `houses` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `name` VARCHAR(128) NOT NULL,
            `location` VARCHAR(128) DEFAULT 'Valentine',
            `price` INT DEFAULT 500,
            `owner_charid` VARCHAR(64) DEFAULT NULL,
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
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            KEY `idx_owner_charid` (`owner_charid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        print("^2[coi_hm]^7 SQL table `houses` normalized schema verified.")

        -- 2. Create relational house_partners table with FK, unique key, and indexes
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `house_partners` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `house_id` INT NOT NULL,
                `partner_charid` VARCHAR(64) NOT NULL,
                `added_by_charid` VARCHAR(64) DEFAULT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY `uk_house_partner` (`house_id`, `partner_charid`),
                KEY `idx_partner_charid` (`partner_charid`),
                KEY `idx_house_id` (`house_id`),
                CONSTRAINT `fk_house_partners_house` FOREIGN KEY (`house_id`) REFERENCES `houses` (`id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]], {}, function()
            print("^2[coi_hm]^7 Relational table `house_partners` verified with FK & Unique constraints.")

            -- Migration 1: Add owner_charid column if missing on legacy installations
            MySQL.query("SHOW COLUMNS FROM `houses` LIKE 'owner_charid'", {}, function(cols)
                if not cols or #cols == 0 then
                    MySQL.query("ALTER TABLE `houses` ADD COLUMN `owner_charid` VARCHAR(64) DEFAULT NULL", {}, function()
                        MySQL.query("ALTER TABLE `houses` ADD INDEX `idx_owner_charid` (`owner_charid`)", {}, function() end)
                    end)
                end
            end)

            -- Migration 2: Drop legacy partners JSON column if present
            MySQL.query("SHOW COLUMNS FROM `houses` LIKE 'partners'", {}, function(cols)
                if cols and #cols > 0 then
                    MySQL.query("ALTER TABLE `houses` DROP COLUMN `partners`", {}, function()
                        print("^2[coi_hm]^7 Migrated and removed legacy `partners` JSON column from `houses`.")
                    end)
                end
            end)

            -- Migration 3: Drop legacy owner name column if present
            MySQL.query("SHOW COLUMNS FROM `houses` LIKE 'owner'", {}, function(cols)
                if cols and #cols > 0 then
                    MySQL.query("ALTER TABLE `houses` DROP COLUMN `owner`", {}, function()
                        print("^2[coi_hm]^7 Removed legacy name-based `owner` column from `houses`.")
                    end)
                end
            end)

            -- Migration 4: Ensure single-door records have valid doors JSON array
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

    SendNotify( src, {
        title = "Housing Creator",
        description = "Access denied.",
        type = "error"
    })
end)

-- Helper to format house object for client payload
local function FormatHouseForClient(h)
    local doors = {}
    local houseLocked = (h.locked == 1 or h.locked == true or h.locked == "1") and 1 or 0
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
    for _, d in ipairs(doors) do
        if d.locked == nil then
            d.locked = houseLocked
        else
            d.locked = (d.locked == 1 or d.locked == true or d.locked == "1") and 1 or 0
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
            heading = tonumber(h.heading) or 0.0,
            locked = houseLocked
        })
    end
    h.doors = doors

    -- Format owner display name dynamically resolved from VORP characters table join
    local ownerName = h.owner_name and h.owner_name:gsub("^%s*(.-)%s*$", "%1") or ""
    if h.status == "available" or not h.owner_charid or h.owner_charid == "" or h.owner_charid == "For Sale" then
        h.owner = "For Sale"
        h.owner_charid = nil
    else
        h.owner = (ownerName ~= "") and ownerName or ("Char #" .. tostring(h.owner_charid))
        h.owner_charid = tostring(h.owner_charid)
    end

    return h
end

-- Helper: Check if player character is house owner
local function IsPlayerHouseOwner(house, charId)
    if not house or not house.owner_charid or not charId then return false end
    return tostring(house.owner_charid) == tostring(charId)
end

-- Helper: Query house_partners relational table to check if player character is a partner
local function IsPlayerHousePartner(houseId, charId, callback)
    if not houseId or not charId then callback(false) return end
    MySQL.query("SELECT 1 FROM house_partners WHERE house_id = ? AND partner_charid = ? LIMIT 1", {
        houseId, tostring(charId)
    }, function(res)
        callback(res and #res > 0)
    end)
end

-- Helper: Check if player character is owner or partner
local function IsPlayerOwnerOrPartner(house, charId, callback)
    if not house or not charId then callback(false) return end
    if IsPlayerHouseOwner(house, charId) then
        callback(true)
        return
    end
    IsPlayerHousePartner(house.id, charId, callback)
end

-- Fetch houses from DB joining VORP characters table dynamically, and sync to client
local function FetchAndSendHouses(target)
    -- Join VORP's characters table on charidentifier to dynamically resolve owner name at query time
    local houseQuery = [[
        SELECT 
            h.*,
            CONCAT(COALESCE(c.firstname, ''), ' ', COALESCE(c.lastname, '')) AS owner_name
        FROM houses h
        LEFT JOIN characters c ON CAST(c.charidentifier AS CHAR) = CAST(h.owner_charid AS CHAR)
        ORDER BY h.id DESC
    ]]

    MySQL.query(houseQuery, {}, function(result)
        local rawHouses = result or {}

        -- Query relational house_partners table joining VORP's characters table to dynamically resolve partner names
        local partnerQuery = [[
            SELECT 
                hp.house_id,
                hp.partner_charid,
                CONCAT(COALESCE(c.firstname, ''), ' ', COALESCE(c.lastname, '')) AS partner_name
            FROM house_partners hp
            LEFT JOIN characters c ON CAST(c.charidentifier AS CHAR) = CAST(hp.partner_charid AS CHAR)
        ]]

        MySQL.query(partnerQuery, {}, function(partnerRows)
            local partnersByHouse = {}
            if partnerRows then
                for _, p in ipairs(partnerRows) do
                    local hId = tonumber(p.house_id)
                    if hId then
                        partnersByHouse[hId] = partnersByHouse[hId] or {}
                        local pName = p.partner_name and p.partner_name:gsub("^%s*(.-)%s*$", "%1") or ""
                        if pName == "" then pName = "Char #" .. tostring(p.partner_charid) end
                        table.insert(partnersByHouse[hId], {
                            charIdentifier = tostring(p.partner_charid),
                            name = pName
                        })
                    end
                end
            end

            local houses = {}
            for _, h in ipairs(rawHouses) do
                local formatted = FormatHouseForClient(h)
                formatted.partners = partnersByHouse[h.id] or {}
                table.insert(houses, formatted)
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
    end)
end

RegisterNetEvent("coi_hm:requestHouses", function()
    local src = source
    FetchAndSendHouses(src)
end)

-- Create / Save House to DB (uses owner_charid)
RegisterNetEvent("coi_hm:createHouse", function(data)
    local src = source
    if not data or not data.doorHash then return end

    local myInfo = GetPlayerOwnerInfo(src)
    local creatorCharId = myInfo.charIdentifier
    local name = (data.name and data.name ~= "") and data.name or ("House #" .. tostring(data.doorHash))
    local location = (data.location and data.location ~= "") and data.location or "Valentine"
    local price = tonumber(data.price) or 500
    local isForSale = (data.owner == "For Sale" or data.status == "available" or data.owner_charid == "For Sale")
    local ownerCharId = isForSale and nil or ((data.owner_charid and data.owner_charid ~= "") and data.owner_charid or creatorCharId)
    local status = isForSale and "available" or "owned"
    local locked = (data.locked ~= nil) and (data.locked and 1 or 0) or 1
    local doorHash = tostring(data.doorHash)
    local modelHash = tostring(data.modelHash or data.model or "")
    local modelName = tostring(data.modelName or "")
    local x = tonumber(data.x) or 0.0
    local y = tonumber(data.y) or 0.0
    local z = tonumber(data.z) or 0.0
    local heading = tonumber(data.heading) or 0.0
    local blipSprite = tonumber(data.blipSprite) or 1586273744
    local blipLabel = data.blipLabel or nil
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
        INSERT INTO houses (name, location, price, owner_charid, status, locked, doorHash, modelHash, modelName, x, y, z, heading, blipSprite, blipLabel, doors, stashLimit)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        name, location, price, ownerCharId, status, locked, doorHash, modelHash, modelName, x, y, z, heading, blipSprite, blipLabel, doorsJson, stashLimit
    }, function(insertId)
        if insertId then
            print(("^2[coi_hm]^7 Created new house #%s (OwnerCharId: '%s', Status: '%s', Price: $%s, Stash: %skg)."):format(insertId, ownerCharId or "None", status, price, stashLimit))
            SendNotify( src, {
                title = "Housing Manager",
                description = ("House saved! OwnerCharId: %s (Stash: %skg)"):format(ownerCharId or "For Sale", stashLimit),
                type = "success"
            })
            FetchAndSendHouses(-1)
        end
    end)
end)

-- Delete House from DB (Cascades delete to house_partners via FK)
RegisterNetEvent("coi_hm:deleteHouse", function(houseId)
    local src = source
    houseId = tonumber(houseId)
    if not houseId then return end

    MySQL.query("DELETE FROM houses WHERE id = ?", { houseId }, function()
        SendNotify( src, {
            title = "Housing Manager",
            description = "House #" .. houseId .. " deleted.",
            type = "info"
        })
        FetchAndSendHouses(-1)
    end)
end)

-- Get Nearby Live Players Event for Ownership Transfer in Edit Modal
RegisterNetEvent("coi_hm:getNearbyPlayers", function()
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = {}

    for _, targetSrcStr in ipairs(GetPlayers()) do
        local targetSrc = tonumber(targetSrcStr)
        if targetSrc then
            local targetPed = GetPlayerPed(targetSrc)
            if DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                if #(coords - targetCoords) <= 35.0 then
                    local info = GetPlayerOwnerInfo(targetSrc)
                    if info.charIdentifier then
                        table.insert(players, {
                            source = targetSrc,
                            charIdentifier = tostring(info.charIdentifier),
                            name = info.name or ("Player #" .. targetSrc)
                        })
                    end
                end
            end
        end
    end

    TriggerClientEvent("coi_hm:receiveNearbyPlayers", src, players)
end)

-- Update House in DB (uses owner_charid)
RegisterNetEvent("coi_hm:updateHouse", function(data)
    local src = source
    if not data or not data.id then return end

    local houseId = tonumber(data.id)
    local name = (data.name and data.name ~= "") and data.name or ("House #" .. houseId)
    local location = (data.location and data.location ~= "") and data.location or "Valentine"
    local price = tonumber(data.price) or 500
    local ownerInput = (data.owner_charid and data.owner_charid ~= "") and data.owner_charid or data.owner
    local isForSale = (ownerInput == "For Sale" or data.status == "available" or not ownerInput or ownerInput == "")
    local ownerCharId = isForSale and nil or ownerInput
    local status = isForSale and "available" or "owned"
    local locked = (data.locked == 1 or data.locked == true or data.locked == "1") and 1 or 0
    local blipSprite = tonumber(data.blipSprite) or 1586273744
    local stashLimit = tonumber(data.stashLimit) or 100

    -- Query characters table to dynamically resolve owner name for default blip label if transferring
    MySQL.query("SELECT CONCAT(COALESCE(firstname,''), ' ', COALESCE(lastname,'')) AS name FROM characters WHERE CAST(charidentifier AS CHAR) = ? LIMIT 1", {
        tostring(ownerCharId or "")
    }, function(charResult)
        local resolvedName = (charResult and #charResult > 0 and charResult[1].name) and charResult[1].name:gsub("^%s*(.-)%s*$", "%1") or nil
        local ownerDisplayName = resolvedName or (ownerCharId and ("Char #" .. ownerCharId) or nil)

        local defaultLabel = isForSale and ("House For Sale ($" .. price .. ")") or (ownerDisplayName and (ownerDisplayName .. "'s House") or "House")
        local blipLabel = (data.blipLabel and data.blipLabel ~= "") and data.blipLabel or defaultLabel

        MySQL.query([[
            UPDATE houses
            SET name = ?, location = ?, price = ?, owner_charid = ?, status = ?, locked = ?, blipSprite = ?, blipLabel = ?, stashLimit = ?
            WHERE id = ?
        ]], {
            name, location, price, ownerCharId, status, locked, blipSprite, blipLabel, stashLimit, houseId
        }, function()
            -- If ownership transferred or reset to for sale, clear old partner associations
            if isForSale or ownerCharId then
                MySQL.query("DELETE FROM house_partners WHERE house_id = ?", { houseId }, function() end)
            end

            print(("^2[coi_hm]^7 Updated house #%s (OwnerCharId: %s, Status: %s, StashLimit: %skg)."):format(houseId, ownerCharId or "None", status, stashLimit))

            -- Live sync updated stashLimit with vorp_inventory
            local inventoryId = "house_stash_" .. tostring(houseId)
            if GetResourceState("vorp_inventory") == "started" and exports.vorp_inventory then
                local invData = {
                    id = inventoryId,
                    name = (name or ("House #" .. houseId)) .. " Storage",
                    limit = stashLimit,
                    acceptWeapons = true,
                    shared = true,
                    ignoreItemStackLimit = true,
                    whitelistItems = false,
                    UsePermissions = false,
                    UseBlackList = false,
                    whitelistWeapons = false
                }
                pcall(function()
                    exports.vorp_inventory:registerInventory(invData)
                end)
            end

            SendNotify( src, {
                title = "Housing Manager",
                description = ("House #%s updated successfully!"):format(houseId),
                type = "success"
            })
            FetchAndSendHouses(-1)
        end)
    end)
end)

-- Buy House with VORP Core cash (Transfers owner_charid and clears old house_partners)
RegisterNetEvent("coi_hm:buyHouse", function(houseId)
    local src = source
    houseId = tonumber(houseId)
    if not houseId then return end

    local myInfo = GetPlayerOwnerInfo(src)
    local buyerCharId = myInfo.charIdentifier

    if not buyerCharId then
        SendNotify( src, {
            title = "Housing Manager",
            description = "You must have an active character to buy a house.",
            type = "error"
        })
        return
    end

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]

        local isForSale = (not house.owner_charid or house.owner_charid == "" or house.status == "available")
        if not isForSale then
            SendNotify( src, {
                title = "Housing Manager",
                description = "This house is not for sale.",
                type = "error"
            })
            return
        end

        local price = tonumber(house.price) or 500

        -- Check player money via VORP Core
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if ok and core and core.getUser then
            local user = core.getUser(src)
            if user then
                local character = user.getUsedCharacter
                if character then
                    local currentMoney = tonumber(character.money) or 0
                    if currentMoney < price then
                        SendNotify( src, {
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

        local buyerName = (myInfo.name and myInfo.name ~= "") and myInfo.name or ("Char #" .. tostring(buyerCharId))
        local newBlipLabel = buyerName .. "'s House"

        -- Update DB: Transfer ownership to buyer's charIdentifier, set status owned, update blipLabel, reset partners
        MySQL.query([[
            UPDATE houses
            SET owner_charid = ?, status = 'owned', locked = 1, blipLabel = ?
            WHERE id = ?
        ]], {
            buyerCharId, newBlipLabel, houseId
        }, function()
            MySQL.query("DELETE FROM house_partners WHERE house_id = ?", { houseId }, function()
                print(("^2[coi_hm]^7 Character '%s' (Src: %s) bought house #%s ('%s') for $%s."):format(buyerCharId, src, houseId, house.name, price))
                SendNotify( src, {
                    title = "Housing Manager",
                    description = ("Congratulations! You purchased '%s' for $%s!"):format(house.name, price),
                    type = "success"
                })
                FetchAndSendHouses(-1)
            end)
        end)
    end)
end)

-- Owner Toggle Door Lock Event (Owner & Partner Permission via charIdentifier)
RegisterNetEvent("coi_hm:toggleDoorLock", function(data)
    local src = source
    local houseId = nil
    local targetDoorHash = nil

    if type(data) == "table" then
        houseId = tonumber(data.houseId)
        targetDoorHash = data.doorHash and tostring(data.doorHash) or nil
    else
        houseId = tonumber(data)
    end

    if not houseId then return end
    local myInfo = GetPlayerOwnerInfo(src)
    if not myInfo.charIdentifier then
        SendNotify( src, {
            title = "Housing Manager",
            description = "No active character found.",
            type = "error"
        })
        return
    end

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]

        IsPlayerOwnerOrPartner(house, myInfo.charIdentifier, function(isOwnerOrPartner)
            if not isOwnerOrPartner then
                SendNotify( src, {
                    title = "Housing Manager",
                    description = "You are not an owner or partner of this house.",
                    type = "error"
                })
                return
            end

            local doors = {}
            if house.doors and house.doors ~= "" then
                local ok, parsed = pcall(json.decode, house.doors)
                if ok and type(parsed) == "table" then doors = parsed end
            end

            local houseLocked = (house.locked == 1 or house.locked == true or house.locked == "1") and 1 or 0

            if #doors == 0 then
                table.insert(doors, {
                    doorHash = tostring(house.doorHash),
                    modelHash = tostring(house.modelHash or ""),
                    modelName = tostring(house.modelName or ""),
                    x = tonumber(house.x) or 0.0,
                    y = tonumber(house.y) or 0.0,
                    z = tonumber(house.z) or 0.0,
                    heading = tonumber(house.heading) or 0.0,
                    locked = houseLocked
                })
            end

            local newDoorStatusStr = ""

            if targetDoorHash then
                local found = false
                for _, d in ipairs(doors) do
                    if tostring(d.doorHash) == targetDoorHash then
                        found = true
                        local currentLock = (d.locked ~= nil) and ((d.locked == 1 or d.locked == true or d.locked == "1") and 1 or 0) or houseLocked
                        d.locked = (currentLock == 1) and 0 or 1
                        newDoorStatusStr = (d.locked == 1) and "Locked" or "Unlocked"
                        break
                    end
                end

                if not found then
                    doors[1].locked = (houseLocked == 1) and 0 or 1
                    newDoorStatusStr = (doors[1].locked == 1) and "Locked" or "Unlocked"
                end
            else
                local newLockState = (houseLocked == 1) and 0 or 1
                houseLocked = newLockState
                for _, d in ipairs(doors) do
                    d.locked = newLockState
                end
                newDoorStatusStr = (newLockState == 1) and "Locked" or "Unlocked"
            end

            local mainDoorLocked = (doors[1] and doors[1].locked ~= nil) and doors[1].locked or houseLocked
            local doorsJson = json.encode(doors)

            MySQL.query("UPDATE houses SET locked = ?, doors = ? WHERE id = ?", { mainDoorLocked, doorsJson, houseId }, function()
                print(("^2[coi_hm]^7 CharId '%s' toggled door #%s lock state on house #%s to %s."):format(myInfo.charIdentifier, targetDoorHash or "all", houseId, newDoorStatusStr))
                SendNotify( src, {
                    title = "Housing Manager",
                    description = ("Door %s!"):format(newDoorStatusStr),
                    type = (newDoorStatusStr == "Locked") and "error" or "success"
                })
                TriggerClientEvent("coi_hm:playDoorSound", src, newDoorStatusStr == "Locked")
                FetchAndSendHouses(-1)
            end)
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
                SendNotify( src, {
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
            SendNotify( src, {
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
            SendNotify( src, {
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
            SendNotify( src, {
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
        SendNotify( src, {
            title = "Housing Manager",
            description = ("Stash position set for House #%s!"):format(houseId),
            type = "success"
        })
        FetchAndSendHouses(-1)
    end)
end)

-- Remove House Stash Coordinates Event
RegisterNetEvent("coi_hm:removeStashCoords", function(data)
    local src = source
    if not data or not data.houseId then return end
    local houseId = tonumber(data.houseId)

    MySQL.query("UPDATE houses SET stashX = NULL, stashY = NULL, stashZ = NULL WHERE id = ?", {
        houseId
    }, function()
        print(("^2[coi_hm]^7 Removed stash position for House #%s."):format(houseId))
        SendNotify( src, {
            title = "Housing Manager",
            description = ("Stash location removed for House #%s!"):format(houseId),
            type = "info"
        })
        FetchAndSendHouses(-1)
    end)
end)

-- Open House Stash Event (vorp_inventory integration - Owner & Partner Access via charIdentifier)
RegisterNetEvent("coi_hm:openStash", function(houseId)
    local src = source
    houseId = tonumber(houseId)
    if not houseId then return end
    local myInfo = GetPlayerOwnerInfo(src)

    if not myInfo.charIdentifier then
        SendNotify( src, {
            title = "Housing Manager",
            description = "No active character loaded.",
            type = "error"
        })
        return
    end

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]

        IsPlayerOwnerOrPartner(house, myInfo.charIdentifier, function(isOwnerOrPartner)
            if not isOwnerOrPartner then
                SendNotify( src, {
                    title = "Housing Manager",
                    description = "Storage access is restricted to house owners and partners.",
                    type = "error"
                })
                return
            end

            local inventoryId = "house_stash_" .. tostring(houseId)
            local stashLimit = tonumber(house.stashLimit) or 100

            if GetResourceState("vorp_inventory") == "started" and exports.vorp_inventory then
                local invData = {
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
                }

                pcall(function()
                    exports.vorp_inventory:registerInventory(invData)
                end)

                exports.vorp_inventory:openInventory(src, inventoryId)
            else
                SendNotify( src, {
                    title = "Housing Manager",
                    description = "vorp_inventory is not running.",
                    type = "error"
                })
            end
        end)
    end)
end)

-- Helper function to fetch and send updated partner data to house owner
local function SendPartnerMenuData(src, houseId)
    local myInfo = GetPlayerOwnerInfo(src)
    if not myInfo or not myInfo.charIdentifier then return end

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]

        if not IsPlayerHouseOwner(house, myInfo.charIdentifier) then
            SendNotify( src, {
                title = "Housing Manager",
                description = "Only the house owner can manage house partners.",
                type = "error"
            })
            return
        end

        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        local nearbyPlayers = {}

        for _, targetSrcStr in ipairs(GetPlayers()) do
            local targetSrc = tonumber(targetSrcStr)
            if targetSrc and targetSrc ~= src then
                local targetPed = GetPlayerPed(targetSrc)
                if DoesEntityExist(targetPed) then
                    local targetCoords = GetEntityCoords(targetPed)
                    if #(coords - targetCoords) <= 15.0 then
                        local targetInfo = GetPlayerOwnerInfo(targetSrc)
                        if targetInfo and targetInfo.charIdentifier then
                            table.insert(nearbyPlayers, {
                                source = targetSrc,
                                charIdentifier = targetInfo.charIdentifier,
                                name = targetInfo.name
                            })
                        end
                    end
                end
            end
        end

        -- Query house_partners joining VORP characters for current partner names
        local q = [[
            SELECT 
                hp.partner_charid,
                CONCAT(COALESCE(c.firstname, ''), ' ', COALESCE(c.lastname, '')) AS partner_name
            FROM house_partners hp
            LEFT JOIN characters c ON CAST(c.charidentifier AS CHAR) = CAST(hp.partner_charid AS CHAR)
            WHERE hp.house_id = ?
        ]]
        MySQL.query(q, { houseId }, function(partnerRows)
            local partners = {}
            if partnerRows then
                for _, p in ipairs(partnerRows) do
                    local pName = p.partner_name and p.partner_name:gsub("^%s*(.-)%s*$", "%1") or ""
                    if pName == "" then pName = "Char #" .. tostring(p.partner_charid) end
                    table.insert(partners, {
                        charIdentifier = tostring(p.partner_charid),
                        name = pName
                    })
                end
            end

            TriggerClientEvent("coi_hm:openPartnerMenu", src, {
                houseId = house.id,
                houseName = house.name,
                partners = partners,
                nearbyPlayers = nearbyPlayers
            })
        end)
    end)
end

-- Request Manage Partners Event (Owner Only - via charIdentifier)
RegisterNetEvent("coi_hm:requestManagePartners", function(data)
    local src = source
    local houseId = (type(data) == "table") and tonumber(data.houseId) or tonumber(data)
    if not houseId then return end
    SendPartnerMenuData(src, houseId)
end)

-- Add Partner Event (Stores in house_partners relational table)
RegisterNetEvent("coi_hm:addPartner", function(data)
    local src = source
    if not data or not data.houseId or not data.partner then return end
    local houseId = tonumber(data.houseId)
    local partnerData = data.partner
    local myInfo = GetPlayerOwnerInfo(src)
    if not myInfo or not myInfo.charIdentifier then return end

    local targetCharId = partnerData.charIdentifier
    if partnerData.source then
        local tInfo = GetPlayerOwnerInfo(tonumber(partnerData.source))
        if tInfo and tInfo.charIdentifier then
            targetCharId = tInfo.charIdentifier
        end
    end

    if not targetCharId or targetCharId == "" then
        SendNotify( src, {
            title = "Housing Manager",
            description = "Could not resolve partner character ID.",
            type = "error"
        })
        return
    end

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]

        if not IsPlayerHouseOwner(house, myInfo.charIdentifier) then return end

        MySQL.query([[
            INSERT INTO house_partners (house_id, partner_charid, added_by_charid)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE id=id
        ]], {
            houseId, tostring(targetCharId), tostring(myInfo.charIdentifier)
        }, function()
            print(("^2[coi_hm]^7 Added partner charId '%s' to House #%s."):format(targetCharId, houseId))
            SendNotify( src, {
                title = "Housing Manager",
                description = "Added player as a house partner!",
                type = "success"
            })
            FetchAndSendHouses(-1)
            SendPartnerMenuData(src, houseId)
        end)
    end)
end)

-- Remove Partner Event (Deletes from house_partners relational table)
RegisterNetEvent("coi_hm:removePartner", function(data)
    local src = source
    if not data or not data.houseId or not data.partner then return end
    local houseId = tonumber(data.houseId)
    local partnerData = data.partner
    local myInfo = GetPlayerOwnerInfo(src)
    if not myInfo or not myInfo.charIdentifier then return end

    local removeCharId = partnerData.charIdentifier or partnerData.partner_charid
    if not removeCharId or removeCharId == "" then return end

    MySQL.query("SELECT * FROM houses WHERE id = ? LIMIT 1", { houseId }, function(result)
        if not result or #result == 0 then return end
        local house = result[1]

        if not IsPlayerHouseOwner(house, myInfo.charIdentifier) then return end

        MySQL.query("DELETE FROM house_partners WHERE house_id = ? AND partner_charid = ?", {
            houseId, tostring(removeCharId)
        }, function()
            print(("^2[coi_hm]^7 Removed partner charId '%s' from House #%s."):format(removeCharId, houseId))
            SendNotify( src, {
                title = "Housing Manager",
                description = "Removed player from house partners.",
                type = "info"
            })
            FetchAndSendHouses(-1)
            SendPartnerMenuData(src, houseId)
        end)
    end)
end)