local assets = game.ReplicatedStorage:WaitForChild("SPH_Assets")
local Packages = game.ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = require(assets.GameConfig)
local modules = assets.Modules
local Enums = require(modules.Enums)
local SP = require(modules.Spring.Default)
local legacySpring = require(modules.LegacySpring)
local WepState = {
	wepStats = nil,
	equipping = Charm.atom(false)						:: Charm.Atom<boolean>,

	gunModel = Charm.atom(nil) 							:: Charm.Atom<Instance>,
	gunAmmo = nil,
	localAmmo = Charm.atom(0)							:: Charm.Atom<number>,
	localUbglAmmo = Charm.atom(0)						:: Charm.Atom<number>,
	predictedChambered = Charm.atom(true)				:: Charm.Atom<boolean>,

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
	Spread = 0,
}
WepState.aimFOVTarget = Charm.computed(function()
	if not WepState.wepStats or not WepState.gunModel() then
		return config.defaultFOV
	end
	return WepState.wepStats.aimFovs[WepState.sightIndex()] or config.defaultFOV
end)

function WepState.adsMeshLayerEnabled(sightIndex: number): boolean
	local w = WepState.wepStats
	if not w or not w.ADSEnabled then
		return false
	end
	local layer = w.ADSEnabled[sightIndex]
	return if layer then true else false
end

function WepState.hasAdsMeshLayers(): boolean
	local v = WepState.wepStats and WepState.wepStats.ADSEnabled
	return if v then true else false
end

WepState.ubglActive = Charm.computed(function()
	local ws = WepState.wepStats
	return ws ~= nil
		and ws.hasUBGL == true
		and WepState.fireMode() == Enums.FireModes.UBGL
end)

WepState.hasAmmoForMode = Charm.computed(function()
	if not WepState.wepStats then
		return false
	end
	if WepState.ubglActive() then
		return WepState.localUbglAmmo() > 0
	elseif WepState.wepStats.openBolt then
		return WepState.localAmmo() > 0
	else
		return WepState.predictedChambered()
	end
end)

WepState.canManipulate = Charm.computed(function()
	return WepState.viewmodelVisible()
	and not WepState.reloading()
	and not WepState.chambering()
	and not WepState.equipping()
	and WepState.wepStats
end)

WepState.canTrackAimInput = Charm.computed(function()
	return not WepState.blocked()
		and not WepState.reloading()
		and not WepState.chambering()
end)

WepState.adsMeshEnabledForActiveSight = Charm.computed(function()
	return WepState.adsMeshLayerEnabled(WepState.sightIndex())
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
	WepState.Spread = 0

	WepState.wepStats = nil
	WepState.gunModel(nil)
	WepState.gunAmmo = nil

	WepState.localAmmo(0)
	WepState.localUbglAmmo(0)
	WepState.predictedChambered(true)
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





WepState.reset()

return WepState