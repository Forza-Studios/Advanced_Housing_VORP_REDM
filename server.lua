local AllowedSteam = {
    ["steam:110000158767928"] = true
}

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