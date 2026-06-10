local Lyra = require("@game/ReplicatedStorage/Packages/Lyra")
local t = require("@game/ReplicatedStorage/Packages/t")
local Players = game:GetService("Players")
const RunService = game:GetService("RunService")

local function syncWithClient(key: string, newData)

end

return function()
    local store = Lyra.createPlayerStore({
        name = "player_data",
        template = {
            hipSens = 1,
            aimSens = 0.5,
        },
        schema = t.strictInterface({
            hipSens = t.number,
            aimSens = t.number,
        }),
        memoryStoreService = if RunService.IsStudio() then Lyra.MockMemoryStoreService.new() else nil,
        dataStoreService = if RunService.IsStudio() then Lyra.MockDataStoreService.new() else nil,
    })

    Players.PlayerAdded:connect(function(player)
        store:loadAsync(player)
    end)

    Players.PlayerRemoving:connect(function(player)
        store:unloadAsync(player)
    end)

    game:BindToClose(function()
        store:closeAsync()
    end)
end
    