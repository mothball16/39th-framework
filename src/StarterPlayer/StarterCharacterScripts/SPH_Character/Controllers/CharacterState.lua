local Packages = game.ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)


local CharacterState = {
	-- Weapon Data
	equipped = nil,
	wepStats = nil,
	attStats = {},
	gunModel = nil,
	gunAmmo = nil,
	
	-- Player Status
	aiming = false,
	sprinting = false,
	reloading = false,
	firstPerson = false,
	dead = false,
	stance = 0,
}

return CharacterState