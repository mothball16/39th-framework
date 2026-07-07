local PlayerKey = require("@game/ReplicatedStorage/Systems/Aware/Core/PlayerKey")

return function(playerKey: string)
	local player = PlayerKey.FromPlayerKey(playerKey)
	local name = player and player.DisplayName or playerKey
	return string.sub(name, 1, 4)
end
