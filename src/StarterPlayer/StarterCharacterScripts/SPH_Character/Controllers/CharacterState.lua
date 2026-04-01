local assets = game.ReplicatedStorage:WaitForChild("SPH_Assets")
local Packages = game.ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = require(assets.GameConfig)

local CharacterState = {
	-- Weapon Data
	wepStats = nil,
	attStats = {},

	gunModel = nil,
	gunAmmo = nil,

	aimSens = Charm.atom(config.defaultAimSensitivity) 	:: Charm.Atom<number>,
	sightIndex = Charm.atom(1) 							:: Charm.Atom<number>,
	aimFOVTarget = 	Charm.atom(config.defaultFOV) 		:: Charm.Atom<number>,

	aiming = Charm.atom(false) 							:: Charm.Atom<boolean>,
	equipped = Charm.atom(nil) 							:: Charm.Atom<Instance>,
	sprinting = Charm.atom(false)						:: Charm.Atom<boolean>,
	reloading = Charm.atom(false)						:: Charm.Atom<boolean>,
	firstPerson = Charm.atom(false)						:: Charm.Atom<boolean>,
	dead = Charm.atom(false)							:: Charm.Atom<boolean>,
	stance = Charm.atom(0) 								:: Charm.Atom<number>,
}

return CharacterState