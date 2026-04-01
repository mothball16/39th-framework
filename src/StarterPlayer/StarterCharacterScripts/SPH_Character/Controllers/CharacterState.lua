local assets = game.ReplicatedStorage:WaitForChild("SPH_Assets")
local Packages = game.ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = require(assets.GameConfig)

local CharacterState = {
	-- Weapon Data
	equipped = nil,
	wepStats = nil,
	attStats = {},



	gunModel = nil,
	gunAmmo = nil,

	aiming = Charm.atom(false) 							:: Charm.Atom<boolean>,
	aimSens = Charm.atom(config.defaultAimSensitivity) 	:: Charm.Atom<number>,
	sightIndex = Charm.atom(1) 							:: Charm.Atom<number>,
	aimFOVTarget = 	Charm.atom(70) 						:: Charm.Atom<number>, -- TODO: use config defaultFOV

	sprinting = Charm.atom(false)						:: Charm.Atom<boolean>,
	reloading = false,
	firstPerson = false,
	dead = false,
	stance = 0,
}

return CharacterState