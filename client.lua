local LoadedHouses = {}

RegisterCommand("hm", function()
    TriggerServerEvent("coi_hm:requestOpen")
end)

RegisterNetEvent("coi_hm:open", function()
    ui = true
    SetNuiFocus(true,true)
    SendNUIMessage({
        action="open",
        data=GetNearestDoorData()
    })
    TriggerServerEvent("coi_hm:requestHouses")
end)

local HouseBlips = {}

local function ClearHouseBlips()
    for _, blip in ipairs(HouseBlips) do
        if DoesBlipExist and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    HouseBlips = {}
end

local function RefreshHouseBlips()
    ClearHouseBlips()
    for _, house in ipairs(LoadedHouses) do
        local hx = tonumber(house.x)
        local hy = tonumber(house.y)
        local hz = tonumber(house.z)
        if hx and hy and hz then
            local sprite = tonumber(house.blipSprite) or 1586273744
            local ownerName = (house.owner and house.owner ~= "" and house.owner ~= "Unowned") and house.owner or nil
            local defaultLabel = ownerName and (ownerName .. "'s House") or "House"
            local label = (house.blipLabel and house.blipLabel ~= "") and house.blipLabel or defaultLabel

            -- Create RedM map blip at house coordinates
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, hx, hy, hz)
            if blip and blip ~= 0 then
                SetBlipSprite(blip, sprite, true)
                Citizen.InvokeNative(0x9CB1A1623062F402, blip, label)
                table.insert(HouseBlips, blip)
            end
        end
    end
end

local MyOwnerInfo = { name = "", steam = "", isAdmin = false }

local function IsPlayerHouseOwner(house)
    if not house or not house.owner or house.owner == "" or house.owner == "Unowned" or house.owner == "For Sale" then
        return false
    end
    local ownerLower = string.lower(tostring(house.owner))
    if MyOwnerInfo.name and string.lower(tostring(MyOwnerInfo.name)) == ownerLower then
        return true
    elseif MyOwnerInfo.steam and string.lower(tostring(MyOwnerInfo.steam)) == ownerLower then
        return true
    elseif MyOwnerInfo.charIdentifier and string.lower(tostring(MyOwnerInfo.charIdentifier)) == ownerLower then
        return true
    end
    return false
end

local function IsPlayerHousePartner(house)
    if not house or not house.partners or type(house.partners) ~= "table" then
        return false
    end
    for _, p in ipairs(house.partners) do
        if type(p) == "table" then
            if p.name and MyOwnerInfo.name and string.lower(tostring(p.name)) == string.lower(tostring(MyOwnerInfo.name)) then
                return true
            elseif p.steam and MyOwnerInfo.steam and string.lower(tostring(p.steam)) == string.lower(tostring(MyOwnerInfo.steam)) then
                return true
            elseif p.charIdentifier and MyOwnerInfo.charIdentifier and string.lower(tostring(p.charIdentifier)) == string.lower(tostring(MyOwnerInfo.charIdentifier)) then
                return true
            end
        elseif type(p) == "string" then
            local pLower = string.lower(p)
            if MyOwnerInfo.name and string.lower(tostring(MyOwnerInfo.name)) == pLower then
                return true
            elseif MyOwnerInfo.steam and string.lower(tostring(MyOwnerInfo.steam)) == pLower then
                return true
            elseif MyOwnerInfo.charIdentifier and string.lower(tostring(MyOwnerInfo.charIdentifier)) == pLower then
                return true
            end
        end
    end
    return false
end

local function IsPlayerOwnerOrPartner(house)
    return IsPlayerHouseOwner(house) or IsPlayerHousePartner(house)
end

RegisterNetEvent("coi_hm:setHouses", function(houses, myInfo)
    LoadedHouses = houses or {}
    if myInfo then
        MyOwnerInfo = myInfo
    end
    SendNUIMessage({
        action = "setHouses",
        houses = LoadedHouses
    })
    ApplyAllDoorLocks()
    RefreshHouseBlips()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        ClearHouseBlips()
    end
end)

RegisterNUICallback("getHouses", function(_, cb)
    TriggerServerEvent("coi_hm:requestHouses")
    cb("ok")
end)

RegisterNUICallback("createHouse", function(data, cb)
    TriggerServerEvent("coi_hm:createHouse", data)
    cb("ok")
end)

RegisterNUICallback("deleteHouse", function(data, cb)
    if data and data.id then
        TriggerServerEvent("coi_hm:deleteHouse", data.id)
    end
    cb("ok")
end)

RegisterNUICallback("updateHouse", function(data, cb)
    if data and data.id then
        TriggerServerEvent("coi_hm:updateHouse", data)
    end
    cb("ok")
end)

RegisterNUICallback("addDoorToHouse", function(data, cb)
    TriggerServerEvent("coi_hm:addDoorToHouse", data)
    cb("ok")
end)

RegisterNUICallback("removeDoorFromHouse", function(data, cb)
    TriggerServerEvent("coi_hm:removeDoorFromHouse", data)
    cb("ok")
end)

RegisterNUICallback("setStashAtCurrentPos", function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    if data and data.houseId then
        TriggerServerEvent("coi_hm:setStashCoords", {
            houseId = data.houseId,
            x = string.format("%.3f", coords.x),
            y = string.format("%.3f", coords.y),
            z = string.format("%.3f", coords.z)
        })
    end
    cb("ok")
end)

RegisterNUICallback("removeStash", function(data, cb)
    if data and data.houseId then
        TriggerServerEvent("coi_hm:removeStashCoords", {
            houseId = data.houseId
        })
    end
    cb("ok")
end)

RegisterNUICallback("close", function(_,cb)
    ui=false
    SetNuiFocus(false,false)
    cb("ok")
end)

RegisterNUICallback("addPartner", function(data, cb)
    TriggerServerEvent("coi_hm:addPartner", data)
    cb("ok")
end)

RegisterNUICallback("removePartner", function(data, cb)
    TriggerServerEvent("coi_hm:removePartner", data)
    cb("ok")
end)

RegisterNUICallback("closePartnerModal", function(_, cb)
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterNUICallback("refresh", function(_,cb)
    TriggerServerEvent("coi_hm:requestHouses")
    cb(GetNearestDoorData())
end)

local function ToPrimitiveNumber(val)
    if type(val) == "number" then return math.floor(val) end
    if type(val) == "string" then return math.floor(tonumber(val) or 0) end
    if type(val) == "boolean" then return val and 1 or 0 end
    if type(val) == "userdata" then
        local str = tostring(val)
        local num = tonumber(str)
        if num then return math.floor(num) end
    end
    return 0
end

local function ToPrimitiveString(val)
    if type(val) == "string" then return val end
    if type(val) == "number" then return tostring(val) end
    if type(val) == "boolean" then return tostring(val) end
    if type(val) == "userdata" then
        local str = tostring(val)
        local num = tonumber(str)
        if num then return tostring(num) end
        return str
    end
    return ""
end

local function SafeGetDoorState(doorHash)
    if not doorHash then return 0 end
    local doorHashNum = ToPrimitiveNumber(doorHash)
    if doorHashNum == 0 then return 0 end

    local state = nil
    if DoorSystemGetDoorState then
        state = DoorSystemGetDoorState(doorHashNum)
    else
        state = Citizen.InvokeNative(0xA39FB38E36C61A28, doorHashNum)
    end

    return ToPrimitiveNumber(state)
end

local function ResolveModelName(doorHash, modelHash)
    local list = RB_DoorHashes or doorhashes
    if not list then return nil end
    doorHash = tonumber(doorHash)
    modelHash = tonumber(modelHash)

    if doorHash and list[doorHash] and type(list[doorHash][3]) == "string" and list[doorHash][3] ~= "" then
        return list[doorHash][3]
    end

    if modelHash then
        for _, info in pairs(list) do
            if tonumber(info[2]) == modelHash and type(info[3]) == "string" and info[3] ~= "" then
                return info[3]
            end
        end
    end
    return nil
end

RegisterNUICallback("scanDoors", function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local radius = tonumber(data and data.radius) or 10.0
    local doors = {}
    local seen = {}

    -- 1. Scan pre-indexed map door database (RB_DoorHashes)
    local db = RB_DoorHashes or doorhashes
    if db then
        for hashKey, info in pairs(db) do
            local doorHash = ToPrimitiveNumber(info[1] or hashKey)
            local dx = coords.x - (tonumber(info[4]) or 0.0)
            local dy = coords.y - (tonumber(info[5]) or 0.0)
            local dz = coords.z - (tonumber(info[6]) or 0.0)
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)

            if d <= radius and doorHash ~= 0 and not seen[doorHash] then
                seen[doorHash] = true
                local modelHash = ToPrimitiveNumber(info[2])
                local modelName = info[3] or ResolveModelName(doorHash, modelHash)
                local doorState = SafeGetDoorState(doorHash)

                table.insert(doors, {
                    doorHash = doorHash,
                    model = modelHash,
                    modelName = ToPrimitiveString(modelName or ("0x" .. string.format("%X", modelHash))),
                    distance = ToPrimitiveString(string.format("%.2f", d)),
                    distNum = tonumber(d) or 0.0,
                    state = doorState,
                    x = ToPrimitiveString(string.format("%.3f", tonumber(info[4]) or 0.0)),
                    y = ToPrimitiveString(string.format("%.3f", tonumber(info[5]) or 0.0)),
                    z = ToPrimitiveString(string.format("%.3f", tonumber(info[6]) or 0.0))
                })
            end
        end
    end

    -- 2. Scan streamed live CObject pool in world
    local objects = GetGamePool("CObject")
    for _, obj in ipairs(objects) do
        if DoesEntityExist(obj) then
            local objCoords = GetEntityCoords(obj)
            local d = #(coords - objCoords)

            if d <= radius then
                local modelHash = ToPrimitiveNumber(GetEntityModel(obj))
                local doorHashPtr = Citizen.PointerValueIntInitialized(0)

                local found = Citizen.InvokeNative(
                    0x589F80B325CC82C5, -- DOOR_SYSTEM_FIND_EXISTING_DOOR
                    objCoords.x, objCoords.y, objCoords.z,
                    modelHash,
                    doorHashPtr
                )

                if found then
                    local doorHashRaw = Citizen.PointerValueInt(doorHashPtr)
                    local doorHash = ToPrimitiveNumber(doorHashRaw)

                    if doorHash ~= 0 and not seen[doorHash] then
                        seen[doorHash] = true
                        local doorState = SafeGetDoorState(doorHash)
                        local modelName = ResolveModelName(doorHash, modelHash)

                        table.insert(doors, {
                            doorHash = doorHash,
                            model = modelHash,
                            modelName = ToPrimitiveString(modelName or ("0x" .. string.format("%X", modelHash))),
                            distance = ToPrimitiveString(string.format("%.2f", d)),
                            distNum = tonumber(d) or 0.0,
                            state = doorState,
                            x = ToPrimitiveString(string.format("%.3f", objCoords.x)),
                            y = ToPrimitiveString(string.format("%.3f", objCoords.y)),
                            z = ToPrimitiveString(string.format("%.3f", objCoords.z))
                        })
                    end
                end
            end
        end
    end

    -- 3. Sort by distance
    table.sort(doors, function(a, b)
        return a.distNum < b.distNum
    end)

    cb({ count = #doors, radius = radius, doors = doors })
end)

function GetNearestDoorData()

    local ped=PlayerPedId()
    local coords=GetEntityCoords(ped)

    local objects=GetGamePool("CObject")

    local closest=nil
    local dist=9999

    for _,obj in ipairs(objects) do

        if DoesEntityExist(obj) then

            local objCoords=GetEntityCoords(obj)
            local d= #(coords-objCoords)

            if d<3.5 and d<dist then
                closest=obj
                dist=d
            end
        end
    end

    if not closest then
        return {
            found=false
        }
    end

    return{
        found=true,
        entity=math.floor(tonumber(closest) or 0),
        model=math.floor(tonumber(GetEntityModel(closest)) or 0),
        distance=string.format("%.2f",dist),
        heading=string.format("%.2f",GetEntityHeading(closest)),
        networked=not not NetworkGetEntityIsNetworked(closest),
        x=string.format("%.3f",coords.x),
        y=string.format("%.3f",coords.y),
        z=string.format("%.3f",coords.z)
    }
end

-- ===== Physical Door Lock Enforcement & 3D Proximity Prompt =====

local function RegisterDoorHash(hash)
    if not hash or hash == 0 then return end
    if IsDoorRegisteredWithSystem and IsDoorRegisteredWithSystem(hash) then return end
    Citizen.InvokeNative(0xD99229FE93B46286, hash, 1, 1, 0, 0, 0, 0)
end

local function SetDoorLockState(hash, isLocked)
    if not hash or hash == 0 then return end
    RegisterDoorHash(hash)
    if isLocked then
        if DoorSystemSetOpenRatio then
            DoorSystemSetOpenRatio(hash, 0.0, false, false)
        else
            Citizen.InvokeNative(0xB6E6FBA95C7324AC, hash, 0.0, true)
        end
        if DoorSystemSetDoorState then
            DoorSystemSetDoorState(hash, 1, false, false)
        else
            Citizen.InvokeNative(0x6BAB9442830C7F53, hash, 1)
        end
    else
        if DoorSystemSetDoorState then
            DoorSystemSetDoorState(hash, 0, false, false)
        else
            Citizen.InvokeNative(0x6BAB9442830C7F53, hash, 0)
        end
    end
end

local function IsDoorLocked(door, houseLocked)
    if door and door.locked ~= nil then
        return (door.locked == 1 or door.locked == true or door.locked == "1")
    end
    return (houseLocked == 1 or houseLocked == true or houseLocked == "1" or houseLocked == nil)
end

function ApplyAllDoorLocks()
    for _, house in ipairs(LoadedHouses) do
        local houseLocked = (house.locked == 1 or house.locked == true or house.locked == "1" or house.locked == nil)
        local doors = (type(house.doors) == "table" and #house.doors > 0) and house.doors or {
            { doorHash = house.doorHash, locked = houseLocked }
        }
        for _, d in ipairs(doors) do
            local doorHash = ToPrimitiveNumber(d.doorHash)
            if doorHash and doorHash ~= 0 then
                local isDoorLocked = IsDoorLocked(d, houseLocked)
                SetDoorLockState(doorHash, isDoorLocked)
            end
        end
    end
end

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen == true or onScreen == 1 or (type(onScreen) == "number" and onScreen > 0) then
        SetTextScale(0.35, 0.35)
        SetTextFontForCurrentCommand(6)
        SetTextColor(255, 255, 255, 240)
        SetTextCentre(1)
        SetTextDropshadow(1, 0, 0, 0, 200)
        local str = CreateVarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
        if str then
            DisplayText(str, _x, _y)
        end
    end
end

-- Auto-request houses on resource start
CreateThread(function()
    Wait(1000)
    TriggerServerEvent("coi_hm:requestHouses")
end)

-- Proximity loop to maintain physical door locks & show owner / buyer prompts
CreateThread(function()
    while true do
        local sleep = 1000
        if #LoadedHouses > 0 then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            for _, house in ipairs(LoadedHouses) do
                local isLocked = (house.locked == 1 or house.locked == true or house.locked == "1" or house.locked == nil)
                local isForSale = (house.owner == "For Sale" or house.status == "available")
                local isOwner = IsPlayerHouseOwner(house)
                local isPartner = IsPlayerHousePartner(house)
                local isOwnerOrPartner = isOwner or isPartner
                local price = tonumber(house.price) or 500

                local doors = (type(house.doors) == "table" and #house.doors > 0) and house.doors or {
                    { doorHash = house.doorHash, x = house.x, y = house.y, z = house.z }
                }

                for _, door in ipairs(doors) do
                    local dx = tonumber(door.x)
                    local dy = tonumber(door.y)
                    local dz = tonumber(door.z)
                    local doorHash = ToPrimitiveNumber(door.doorHash)
                    local isDoorLocked = IsDoorLocked(door, house.locked)

                    if dx and dy and dz then
                        local dist = #(coords - vector3(dx, dy, dz))

                        if dist <= 25.0 then
                            sleep = 0

                            -- Continuously enforce physical door state in game engine per door
                            if doorHash and doorHash ~= 0 then
                                SetDoorLockState(doorHash, isDoorLocked)
                            end

                            if isForSale then
                                -- Show 3D For Sale Prompt when near door (within 5.0m)
                                if dist <= 5.0 then
                                    local text = "~g~HOUSE FOR SALE~s~\nPrice: ~g~$" .. tostring(price) .. "~s~\nPress ~e~[E]~s~ to Purchase"
                                    DrawText3D(dx, dy, dz + 0.15, text)

                                    if dist <= 2.5 and IsControlJustPressed(0, 0xCEFD9220) then
                                        TriggerServerEvent("coi_hm:buyHouse", house.id)
                                        Wait(1000)
                                    end
                                end
                            elseif isOwner then
                                -- House Owner: Show 3D Lock/Unlock Toggle & Partner Management Prompts (within 5.0m)
                                if dist <= 5.0 then
                                    local lockStatusStr = isDoorLocked and "~e~Locked~s~" or "~g~Unlocked~s~"
                                    local actionStr = isDoorLocked and "Press ~e~[G]~s~ to Unlock Door" or "Press ~e~[G]~s~ to Lock Door"
                                    local text = "~g~YOUR HOUSE~s~\nDoor: " .. lockStatusStr .. "\n" .. actionStr .. "\nPress ~e~[J]~s~ to Manage Partners"
                                    DrawText3D(dx, dy, dz + 0.15, text)

                                    if dist <= 2.5 and IsControlJustPressed(0, 0x760A9C6F) then -- G key
                                        TriggerServerEvent("coi_hm:toggleDoorLock", { houseId = house.id, doorHash = door.doorHash })
                                        Wait(1000)
                                    elseif dist <= 2.5 and IsControlJustPressed(0, 0xF3830D8E) then -- J key
                                        TriggerServerEvent("coi_hm:requestManagePartners", { houseId = house.id })
                                        Wait(1000)
                                    end
                                end
                            elseif isPartner then
                                -- House Partner: Show 3D Lock/Unlock Toggle Prompt (within 5.0m)
                                if dist <= 5.0 then
                                    local lockStatusStr = isDoorLocked and "~e~Locked~s~" or "~g~Unlocked~s~"
                                    local actionStr = isDoorLocked and "Press ~e~[G]~s~ to Unlock Door" or "Press ~e~[G]~s~ to Lock Door"
                                    local text = "~g~PARTNER HOUSE~s~\nDoor: " .. lockStatusStr .. "\n" .. actionStr
                                    DrawText3D(dx, dy, dz + 0.15, text)

                                    if dist <= 2.5 and IsControlJustPressed(0, 0x760A9C6F) then -- G key
                                        TriggerServerEvent("coi_hm:toggleDoorLock", { houseId = house.id, doorHash = door.doorHash })
                                        Wait(1000)
                                    end
                                end
                            else
                                -- Non-owner: Show 3D text prompt when near locked door (within 5.0m)
                                if dist <= 5.0 and isDoorLocked then
                                    local ownerName = (house.owner and house.owner ~= "") and house.owner or "Owner"
                                    local text = "~e~Door Locked~s~\nContact ~y~" .. tostring(ownerName) .. "~s~ for access"
                                    DrawText3D(dx, dy, dz + 0.15, text)
                                end
                            end
                        end
                    end
                end

                -- Check House Stash Location Interaction ([G] key - Owner & Partner Access)
                local sx = tonumber(house.stashX)
                local sy = tonumber(house.stashY)
                local sz = tonumber(house.stashZ)
                if sx and sy and sz then
                    local sDist = #(coords - vector3(sx, sy, sz))
                    if sDist <= 2.5 then
                        sleep = 0
                        if isOwnerOrPartner then
                            local limit = tonumber(house.stashLimit) or 100
                            local text = "~g~HOUSE STASH~s~\nCapacity: ~g~" .. tostring(limit) .. " kg~s~\nPress ~e~[G]~s~ to Open Storage"
                            DrawText3D(sx, sy, sz + 0.15, text)

                            if sDist <= 2.0 and IsControlJustPressed(0, 0x760A9C6F) then -- G key
                                TriggerServerEvent("coi_hm:openStash", house.id)
                                Wait(1000)
                            end
                        else
                            local text = "~e~HOUSE STASH~s~\nOwner & Partner Access Only"
                            DrawText3D(sx, sy, sz + 0.15, text)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Open Partner Management Menu Event Handler
RegisterNetEvent("coi_hm:openPartnerMenu", function(data)
    if not data or not data.houseId then return end
    local houseId = data.houseId
    local houseName = data.houseName or ("House #" .. houseId)
    local partners = data.partners or {}
    local nearbyPlayers = data.nearbyPlayers or {}

    if lib and lib.registerContext and lib.showContext then
        local options = {}

        table.insert(options, {
            title = "➕ Add Nearby Player as Partner",
            description = #nearbyPlayers > 0 and ("Found " .. #nearbyPlayers .. " nearby player(s) within 15m") or "No nearby players found (within 15m)",
            disabled = true
        })

        for _, p in ipairs(nearbyPlayers) do
            local targetPlayer = p
            table.insert(options, {
                title = "👤 " .. (targetPlayer.name or ("Player #" .. targetPlayer.source)),
                description = "Click to add as house partner",
                icon = "user-plus",
                onSelect = function()
                    TriggerServerEvent("coi_hm:addPartner", { houseId = houseId, partner = targetPlayer })
                end
            })
        end

        table.insert(options, {
            title = "👥 Current House Partners (" .. #partners .. ")",
            description = #partners > 0 and "Click a partner below to remove them" or "No partners added yet",
            disabled = true
        })

        for _, p in ipairs(partners) do
            local partnerItem = p
            local pName = (type(partnerItem) == "table" and partnerItem.name) or tostring(partnerItem)
            table.insert(options, {
                title = "👤 " .. pName,
                description = "Click to remove partner access",
                icon = "user-minus",
                onSelect = function()
                    TriggerServerEvent("coi_hm:removePartner", { houseId = houseId, partner = (type(partnerItem) == "table" and partnerItem or { name = partnerItem }) })
                end
            })
        end

        lib.registerContext({
            id = "coi_hm_partners_" .. houseId,
            title = "🤝 House Partners — " .. houseName,
            options = options
        })
        lib.showContext("coi_hm_partners_" .. houseId)
    else
        SendNUIMessage({
            action = "openPartnerModal",
            data = data
        })
        SetNuiFocus(true, true)
    end
end)