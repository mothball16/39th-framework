local assets = game.ReplicatedStorage:WaitForChild("SPH_Assets")
local Packages = game.ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = require(assets.GameConfig)

local WepState = {
	wepStats = nil,
	attStats = {},

	gunModel = nil,
	gunAmmo = nil,

	aimSens = Charm.atom(config.defaultAimSensitivity) 	:: Charm.Atom<number>,
	sightIndex = Charm.atom(1) 							:: Charm.Atom<number>,
	viewmodelVisible = Charm.atom(false)				:: Charm.Atom<boolean>,
	reloading = Charm.atom(false)						:: Charm.Atom<boolean>,
	chambering = Charm.atom(false)						:: Charm.Atom<boolean>,
	aimHeld = Charm.atom(false)							:: Charm.Atom<boolean>,
	blocked = Charm.atom(false)							:: Charm.Atom<boolean>,

	laserEnabled = Charm.atom(false)					:: Charm.Atom<boolean>,
	flashlightEnabled = Charm.atom(false)				:: Charm.Atom<boolean>,
	bipodEnabled = Charm.atom(false)					:: Charm.Atom<boolean>,
	fireMode = Charm.atom(0)							:: Charm.Atom<number>,
	holdStance = Charm.atom(0)							:: Charm.Atom<number>,
}

return WepState