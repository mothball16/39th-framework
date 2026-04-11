local assets = game.ReplicatedStorage:WaitForChild("SPH_Assets")
local Packages = game.ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = require(assets.GameConfig)
local Enums = require(script.Parent.Parent.Enums)
local modules = assets.Modules
local SP = require(modules.Spring.Default)
local legacySpring = require(modules.LegacySpring)
local WepState = {
	wepStats = nil,
	attStats = {},
	equipping = Charm.atom(false)						:: Charm.Atom<boolean>,

	gunModel = Charm.atom(nil) 							:: Charm.Atom<Instance>,
	gunAmmo = nil,
	localAmmo = Charm.atom(0)							:: Charm.Atom<number>,

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

	CameraSpring = legacySpring.new(Vector3.new()),
	RecoilPos = legacySpring.new(Vector3.new()),
	RecoilDir = legacySpring.new(Vector3.new()),
	RecoilUp = legacySpring.new(Vector3.new()),
	RecoilCF = CFrame.new(),
	RecoilFactor = 0,
}
WepState.aimFOVTarget = Charm.computed(function()
	if not WepState.wepStats or not WepState.gunModel() then
		return config.defaultFOV
	end
	return WepState.wepStats.aimFovs[WepState.sightIndex()] or config.defaultFOV
end)

function WepState.reset()
	WepState.RecoilUp.s = SP.rs
	WepState.RecoilUp.d = SP.rd
	WepState.RecoilPos.s = SP.rs
	WepState.RecoilPos.d = SP.rd
	WepState.RecoilDir.s = SP.rs
	WepState.RecoilDir.d = SP.rd
	WepState.CameraSpring.s = SP.cs
	WepState.CameraSpring.d = SP.cd
	WepState.RecoilCF = CFrame.new()
	WepState.RecoilFactor = 0

	WepState.wepStats = nil
	WepState.attStats = {}
	WepState.gunModel(nil)
	WepState.gunAmmo = nil

	WepState.localAmmo(0)
	WepState.aimSens(config.defaultAimSensitivity)
	WepState.sightIndex(1)
	WepState.viewmodelVisible(false)
	WepState.reloading(false)
	WepState.chambering(false)
	WepState.aimHeld(false)
	WepState.blocked(false)
	WepState.laserEnabled(false)
	WepState.flashlightEnabled(false)
	WepState.bipodEnabled(false)
	WepState.fireMode(0)
	WepState.holdStance(Enums.HoldStance.Ready)
	WepState.equipping(false)
end

function WepState.canManipulate()
	return WepState.viewmodelVisible()
	and not WepState.reloading()
	and not WepState.chambering()
	and not WepState.equipping()
	and WepState.wepStats
end

WepState.reset()

return WepState