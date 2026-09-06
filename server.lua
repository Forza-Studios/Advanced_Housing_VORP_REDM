local AllowedSteam = {
    ["steam:110000158767928"] = true
}

-- Helper function to resolve player creator / character owner name
local function GetPlayerOwnerId(src)
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
                    local charIdentifier = character.charidentifier
                    if fullName ~= "" then
                        return fullName
                    elseif charIdentifier then
                        return "Char #" .. tostring(charIdentifier)
                    end
                end
            end
        end
    end

    -- Fallback to identifiers (Steam, License, or Player Name)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(id, 1, 6) == "steam:" then
            return id
        end
    end
    return GetPlayerName(src) or "Unknown Creator"
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
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function(result)
        print("^2[coi_hm]^7 SQL table `houses` initialized successfully.")
        -- Migration check for existing table without locked, blipSprite, blipLabel columns
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `locked` TINYINT(1) DEFAULT 1;
        ]], {}, function() end)
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `blipSprite` BIGINT DEFAULT 1586273744;
        ]], {}, function() end)
        MySQL.query([[
            ALTER TABLE `houses` ADD COLUMN IF NOT EXISTS `blipLabel` VARCHAR(128) DEFAULT NULL;
        ]], {}, function() end)
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

-- Fetch houses from DB and sync to client
local function FetchAndSendHouses(target)
    MySQL.query("SELECT * FROM houses ORDER BY id DESC", {}, function(result)
        local houses = result or {}
        TriggerClientEvent("coi_hm:setHouses", target or -1, houses)
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

    MySQL.insert([[
        INSERT INTO houses (name, location, price, owner, status, locked, doorHash, modelHash, modelName, x, y, z, heading, blipSprite, blipLabel)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        name, location, price, owner, status, locked, doorHash, modelHash, modelName, x, y, z, heading, blipSprite, blipLabel
    }, function(insertId)
        if insertId then
            print(("^2[coi_hm]^7 Created new house #%s (Owner: '%s', Status: '%s', Price: $%s)."):format(insertId, owner, status, price))
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = ("House saved! Owner: %s (Status: %s)"):format(owner, status),
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

    MySQL.query([[
        UPDATE houses
        SET name = ?, location = ?, price = ?, owner = ?, status = ?, locked = ?, blipSprite = ?, blipLabel = ?
        WHERE id = ?
    ]], {
        name, location, price, owner, status, locked, blipSprite, blipLabel, houseId
    }, function(result)
        print(("^2[coi_hm]^7 Updated house #%s (Owner: %s, Status: %s)."):format(houseId, owner, status))
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