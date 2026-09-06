local AllowedSteam = {
    ["steam:110000158767928"] = true
}

-- ===== SQL Auto-Executor =====
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
            `status` VARCHAR(32) DEFAULT 'available',
            `doorHash` VARCHAR(64) NOT NULL,
            `modelHash` VARCHAR(64) DEFAULT NULL,
            `modelName` VARCHAR(128) DEFAULT NULL,
            `x` FLOAT NOT NULL,
            `y` FLOAT NOT NULL,
            `z` FLOAT NOT NULL,
            `heading` FLOAT DEFAULT 0.0,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function(result)
        print("^2[coi_hm]^7 SQL table `houses` initialized successfully.")
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

    local name = (data.name and data.name ~= "") and data.name or ("House #" .. tostring(data.doorHash))
    local location = (data.location and data.location ~= "") and data.location or "Valentine"
    local price = tonumber(data.price) or 500
    local owner = (data.owner and data.owner ~= "") and data.owner or nil
    local status = data.status or "available"
    local doorHash = tostring(data.doorHash)
    local modelHash = tostring(data.modelHash or data.model or "")
    local modelName = tostring(data.modelName or "")
    local x = tonumber(data.x) or 0.0
    local y = tonumber(data.y) or 0.0
    local z = tonumber(data.z) or 0.0
    local heading = tonumber(data.heading) or 0.0

    MySQL.insert([[
        INSERT INTO houses (name, location, price, owner, status, doorHash, modelHash, modelName, x, y, z, heading)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        name, location, price, owner, status, doorHash, modelHash, modelName, x, y, z, heading
    }, function(insertId)
        if insertId then
            print(("^2[coi_hm]^7 Saved house #%s into SQL table `houses`."):format(insertId))
            TriggerClientEvent("ox_lib:notify", src, {
                title = "Housing Manager",
                description = "House saved successfully!",
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