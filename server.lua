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
    local owner = (data.owner and data.owner ~= "") and data.owner or creatorOwner
    local status = "owned"
    local locked = (data.locked ~= nil) and (data.locked and 1 or 0) or 1 -- default locked = true (1)
    local doorHash = tostring(data.doorHash)
    local modelHash = tostring(data.modelHash or data.model or "")
    local modelName = tostring(data.modelName or "")
    local x = tonumber(data.x) or 0.0
    local y = tonumber(data.y) or 0.0
    local z = tonumber(data.z) or 0.0
    local heading = tonumber(data.heading) or 0.0
    local blipSprite = tonumber(data.blipSprite) or 1586273744
    local blipLabel = (data.blipLabel and data.blipLabel ~= "") and data.blipLabel or (owner .. "'s House")

    MySQL.insert([[
        INSERT INTO houses (name, location, price, owner, status, locked, doorHash, modelHash, modelName, x, y, z, heading, blipSprite, blipLabel)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        name, location, price, owner, status, locked, doorHash, modelHash, modelName, x, y, z, heading, blipSprite, blipLabel
    }, function(insertId)
        if insertId then
            print(("^2[coi_hm]^7 Created new house #%s owned by '%s' (Locked: %s, Blip: %s)."):format(insertId, owner, tostring(locked == 1), blipLabel))
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = ("House saved! Owner: %s (Blip: %s)"):format(owner, blipLabel),
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
    local owner = (data.owner and data.owner ~= "") and data.owner or "Unowned"
    local locked = (data.locked == 1 or data.locked == true or data.locked == "1") and 1 or 0
    local status = (owner ~= "Unowned" and owner ~= "") and "owned" or "available"
    local blipSprite = tonumber(data.blipSprite) or 1586273744
    local blipLabel = (data.blipLabel and data.blipLabel ~= "") and data.blipLabel or ((owner ~= "Unowned" and owner ~= "") and (owner .. "'s House") or "House")

    MySQL.query([[
        UPDATE houses
        SET name = ?, location = ?, price = ?, owner = ?, status = ?, locked = ?, blipSprite = ?, blipLabel = ?
        WHERE id = ?
    ]], {
        name, location, price, owner, status, locked, blipSprite, blipLabel, houseId
    }, function(result)
        print(("^2[coi_hm]^7 Updated house #%s (Owner: %s, Blip: %s)."):format(houseId, owner, blipLabel))
        TriggerClientEvent("ox_lib:notify", src, {
            title = "Housing Manager",
            description = ("House #%s updated successfully!"):format(houseId),
            type = "success"
        })
        FetchAndSendHouses(-1)
    end)
end)