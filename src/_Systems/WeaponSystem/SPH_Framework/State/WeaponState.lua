local Framework = script:FindFirstAncestor("SPH_Framework")
local Access = require(Framework.Access)
local Packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = Access.config
local Enums = require(Framework.Core.Enums)
local Types = require(Framework.Core.ConfigurationTypes)
local SP = require(Framework.Weapons.Spring.Default)
local legacySpring = require(Framework.Weapons.LegacySpring)
local Maid = require(Packages.maid)

local WepState = {}
WepState.__index = WepState

type Spring = typeof(legacySpring.new(Vector3.new()))

type self = {
	wepStats: Charm.Atom<Types.WeaponStats?>,
	equipping: Charm.Atom<boolean>,
	equipped: Charm.Atom<boolean>,

	gunModel: Charm.Atom<Model?>,
	gunAmmo: Instance?,
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

	maid: Maid.Maid,
	CameraSpring: Spring,
	RecoilPos: Spring,
	RecoilDir: Spring,
	RecoilUp: Spring,
	RecoilCF: CFrame,
	RecoilFactor: number,
	Spread: number,

	ubglActive: Charm.Selector<boolean>,
	hasAmmoForMode: Charm.Selector<boolean>,
	canManipulate: Charm.Selector<boolean>,
	canTrackAimInput: Charm.Selector<boolean>,
	adsMeshEnabledForActiveSight: Charm.Selector<boolean>,
	hasAdsMeshLayers: Charm.Selector<boolean>,
	aimLerpFactor: Charm.Selector<number>,
	aimCamLerpFactor: Charm.Selector<number>,
}

export type WeaponState = typeof(setmetatable({} :: self, WepState))

function WepState.new(): WeaponState
	local self = setmetatable({
		wepStats = Charm.atom(nil),
		equipping = Charm.atom(false),
		equipped = Charm.atom(false),

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

	self.adsMeshEnabledForActiveSight = Charm.computed(function()
		return self:ADSMeshLayerEnabled(self.sightIndex())
	end)

	self.hasAdsMeshLayers = Charm.computed(function()
		local ws = self.wepStats()
		local v = ws and ws.ADSEnabled
		return v and true or false
	end)

	self.aimLerpFactor = Charm.computed(function()
		local ws = self.wepStats()
		if ws then
			-- how large of a step we need to hit 99% progress in ws.aimTime seconds assuming 60hz
			local steps = 60 * ws.aimTime
			return 1 - math.pow(0.01, 1 / steps)
		end

		return 0.1
	end)

	self.aimCamLerpFactor = Charm.computed(function()
		local ws = self.wepStats()
		if ws then
			-- how large of a step we need to hit 99% progress in ws.aimTime seconds assuming 60hz
			local steps = 60 * (ws.aimTime / 1.25)
			return 1 - math.pow(0.01, 1 / steps)
		end

		return 0.125
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
	self.equipped(false)

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
