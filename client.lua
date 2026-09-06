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
end)

RegisterNUICallback("close", function(_,cb)
    ui=false
    SetNuiFocus(false,false)
    cb("ok")
end)

RegisterNUICallback("refresh", function(_,cb)
    cb(GetNearestDoorData())
end)

RegisterNUICallback("scanDoors", function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local objects = GetGamePool("CObject")
    local radius = data.radius or 10.0
    local doors = {}

    for _, obj in ipairs(objects) do
        if DoesEntityExist(obj) then
            local objCoords = GetEntityCoords(obj)
            local d = #(coords - objCoords)

            if d <= radius then
                table.insert(doors, {
                    entity = obj,
                    model = GetEntityModel(obj),
                    distance = string.format("%.2f", d),
                    heading = string.format("%.2f", GetEntityHeading(obj)),
                    networked = NetworkGetEntityIsNetworked(obj),
                    x = string.format("%.3f", objCoords.x),
                    y = string.format("%.3f", objCoords.y),
                    z = string.format("%.3f", objCoords.z)
                })
            end
        end
    end

    -- Sort by distance
    table.sort(doors, function(a, b)
        return tonumber(a.distance) < tonumber(b.distance)
    end)

    cb({ count = #doors, doors = doors })
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
        entity=closest,
        model=GetEntityModel(closest),
        distance=string.format("%.2f",dist),
        heading=string.format("%.2f",GetEntityHeading(closest)),
        networked=NetworkGetEntityIsNetworked(closest),
        x=string.format("%.3f",coords.x),
        y=string.format("%.3f",coords.y),
        z=string.format("%.3f",coords.z)
    }
end