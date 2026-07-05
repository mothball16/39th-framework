--!strict
local Players = game:GetService("Players")
local PlayerKey = {}

function PlayerKey.ToPlayerKey(player: Player): string
    return tostring(player.UserId)
end

function PlayerKey.FromPlayerKey(key: string): Player
    local player = Players:GetPlayerByUserId(tonumber(key) :: number)
    if not player then
        error(`Player not found for key: {key}`)
    end
    return player :: Player
end

return PlayerKey