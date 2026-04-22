local sph = require(game.ReplicatedStorage.SPH_Framework.Core.GameAccess)
local modules = sph.framework
local Packages = game.ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = sph.config
local Enums = require(modules.Core.Enums)
local SP = require(modules.Weapons.Spring.Default)
local legacySpring = require(modules.Weapons.LegacySpring)
local Maid = require(Packages.maid)



local WepState = {}
WepState.__index = WepState
type self = {
	-- atoms (callable)
	wepStats: Charm.Atom<any>,
	equipping: Charm.Atom<boolean>,

	gunModel: Charm.Atom<Instance?>,
	gunAmmo: any,
	localAmmo: Charm.Atom<number>,
	localUbglAmmo: Charm.Atom<number>,

	aimSens: Charm.Atom<number>,
	sightIndex: Charm.Atom<number>,
	viewmodelVisible: Charm.Atom<boolean>,
	reloading: Charm.Atom<boolean>,
	chambering: Charm.Atom<boolean>,
	aimHeld: Charm.Atom<boolean>,
	blocked: Charm.Atom<boolean>,

	laserEnabled: Charm.Atom<boolean>,
	flashlightEnabled: Charm.Atom<boolean>,
	bipodEnabled: Charm.Atom<boolean>,
	fireMode: Charm.Atom<number>,
	holdStance: Charm.Atom<number>,

	-- computed (callable)
	ubglActive: Charm.Getter<boolean>,
	hasAmmoForMode: Charm.Getter<boolean>,
	canManipulate: Charm.Getter<boolean>,
	canTrackAimInput: Charm.Getter<boolean>,
	aimFOVTarget: Charm.Getter<number>,
	adsMeshEnabledForActiveSight: Charm.Getter<boolean>,
	hasAdsMeshLayers: Charm.Getter<boolean>,

	-- non-atoms
	maid: any,
	CameraSpring: any,
	RecoilPos: any,
	RecoilDir: any,
	RecoilUp: any,
	RecoilCF: CFrame,
	RecoilFactor: number,
	Spread: number,
}

export type WeaponState = typeof(setmetatable({}, WepState))

function WepState.new()
	local self = setmetatable({
		wepStats = Charm.atom(nil),
		equipping = Charm.atom(false),

		gunModel = Charm.atom(nil),
		gunAmmo = nil,
		localAmmo = Charm.atom(0),
		localUbglAmmo = Charm.atom(0),

		aimSens = Charm.atom(config.defaultAimSensitivity),
		sightIndex = Charm.atom(1),
		viewmodelVisible = Charm.atom(false),
		reloading = Charm.atom(false),
		chambering = Charm.atom(false),
		aimHeld = Charm.atom(false),
		blocked = Charm.atom(false),

		laserEnabled = Charm.atom(false),
		flashlightEnabled = Charm.atom(false),
		bipodEnabled = Charm.atom(false),
		fireMode = Charm.atom(0),
		holdStance = Charm.atom(0),

		-- non-atoms
		maid = Maid.new(),
		CameraSpring = legacySpring.new(Vector3.new()),
		RecoilPos = legacySpring.new(Vector3.new()),
		RecoilDir = legacySpring.new(Vector3.new()),
		RecoilUp = legacySpring.new(Vector3.new()),
		RecoilCF = CFrame.new(),
		RecoilFactor = 0,
		Spread = 0,
	} :: self, WepState)

	self.ubglActive = Charm.computed(function()
		local ws = self.wepStats()
		return ws ~= nil and ws.hasUBGL == true and self.fireMode() == Enums.FireModes.UBGL
	end)

	self.hasAmmoForMode = Charm.computed(function()
		local ws = self.wepStats()
		if not ws then
			return false
		end
		if self.ubglActive() then
			return self.localUbglAmmo() > 0
		else
			return self.localAmmo() > 0
		end
	end)

	self.canManipulate = Charm.computed(function()
		return self.viewmodelVisible()
			and not self.reloading()
			and not self.chambering()
			and not self.equipping()
			and self.wepStats()
	end)

	self.canTrackAimInput = Charm.computed(function()
		return not self.blocked() and not self.reloading() and not self.chambering()
	end)

	self.aimFOVTarget = Charm.computed(function()
		local stat = self.wepStats()
		if not stat or not self.gunModel() then
			return config.defaultFOV
		end
		return stat.aimFovs[self.sightIndex()] or config.defaultFOV
	end)

	self.adsMeshEnabledForActiveSight = Charm.computed(function()
		return self:ADSMeshLayerEnabled(self.sightIndex())
	end)

	self.hasAdsMeshLayers = Charm.computed(function()
		local ws = self.wepStats()
		local v = ws and ws.ADSEnabled
		return v and true or false
	end)
	return self
end

function WepState:ADSMeshLayerEnabled(sightIndex: number): boolean
	local stat = self.wepStats()
	if not stat or not stat.ADSEnabled then
		return false
	end
	return stat.ADSEnabled[sightIndex] and true or false
end

function WepState:Reset()
	self.RecoilUp.s = SP.rs
	self.RecoilUp.d = SP.rd
	self.RecoilPos.s = SP.rs
	self.RecoilPos.d = SP.rd
	self.RecoilDir.s = SP.rs
	self.RecoilDir.d = SP.rd
	self.CameraSpring.s = SP.cs
	self.CameraSpring.d = SP.cd
	self.RecoilCF = CFrame.new()
	self.RecoilFactor = 0
	self.Spread = 0

	self.wepStats(nil)
	self.gunModel(nil)
	self.gunAmmo = nil

	self.localAmmo(0)
	self.localUbglAmmo(0)
	self.aimSens(config.defaultAimSensitivity)
	self.sightIndex(1)
	self.viewmodelVisible(false)
	self.reloading(false)
	self.chambering(false)
	self.aimHeld(false)
	self.blocked(false)
	self.laserEnabled(false)
	self.flashlightEnabled(false)
	self.bipodEnabled(false)
	self.fireMode(0)
	self.holdStance(Enums.HoldStance.Ready)
	self.equipping(false)

	self.maid:DoCleaning()
end

return WepState
