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
	aimFOVTarget = 	Charm.atom(config.defaultFOV) 		:: Charm.Atom<number>,

	sprinting = Charm.atom(false)						:: Charm.Atom<boolean>,
	reloading = Charm.atom(false)						:: Charm.Atom<boolean>,
	firstPerson = Charm.atom(false)						:: Charm.Atom<boolean>,
	dead = Charm.atom(false)							:: Charm.Atom<boolean>,
	stance = 0,
}

return CharacterState