local ui = false

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

RegisterNetEvent("coi_hm:setHouses", function(houses)
    SendNUIMessage({
        action = "setHouses",
        houses = houses or {}
    })
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

RegisterNUICallback("close", function(_,cb)
    ui=false
    SetNuiFocus(false,false)
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