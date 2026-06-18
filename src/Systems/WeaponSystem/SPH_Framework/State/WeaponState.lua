local Framework = script:FindFirstAncestor("SPH_Framework")
local Access = require(Framework.Access)
local Packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = Access.config
local Enums = require(Framework.Core.Enums)
local Types = require(Framework.Core.ConfigurationTypes)
local Ripple = require(Packages.ripple)
local Maid = require(Packages.maid)

local WepState = {}
WepState.__index = WepState

local RECOIL_SPRING = { frequency = 48 / (2 * math.pi), dampingRatio = 0.36, start = false }
local CAMERA_SPRING = { frequency = 64 / (2 * math.pi), dampingRatio = 1, start = false }

type self = {
	wepStats: Charm.Atom<Types.WeaponStats?>,
	equipping: Charm.Atom<boolean>,
	equipped: Charm.Atom<boolean>,

	gunModel: Charm.Atom<Model?>,
	gunAmmo: Instance?,
	localAmmo: Charm.Atom<number>,

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
	CameraSpring: Ripple.Spring<Vector3>,
	RecoilPos: Ripple.Spring<Vector3>,
	RecoilDir: Ripple.Spring<Vector3>,
	RecoilUp: Ripple.Spring<Vector3>,
	RecoilCF: CFrame,
	RecoilRot: Ripple.Spring,

	RecoilFactor: number,
	Spread: number,

	hasAmmoForMode: Charm.Getter<boolean>,
	canManipulate: Charm.Getter<boolean>,
	canTrackAimInput: Charm.Getter<boolean>,
	adsMeshEnabledForActiveSight: Charm.Getter<boolean>,
	hasAdsMeshLayers: Charm.Getter<boolean>,
	aimLerpFactor: Charm.Getter<number>,
	aimCamLerpFactor: Charm.Getter<number>,
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
		CameraSpring = Ripple.createSpring(Vector3.zero, CAMERA_SPRING),
		RecoilPos = Ripple.createSpring(Vector3.zero, RECOIL_SPRING),
		RecoilDir = Ripple.createSpring(Vector3.zero, RECOIL_SPRING),
		RecoilUp = Ripple.createSpring(Vector3.zero, RECOIL_SPRING),
		RecoilRot = Ripple.createSpring(0, {
			tension = 500,
			mass = 2,
			friction = 50,
			start = false,
		}),
		RecoilCF = CFrame.new(),
		RecoilFactor = 0,
		Spread = 0,
	} :: self, WepState)

	self.hasAmmoForMode = Charm.computed(function()
		return self.localAmmo() > 0
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

function WepState.ADSMeshLayerEnabled(self: WeaponState, sightIndex: number): boolean
	local stat = self.wepStats()
	if not stat or not stat.ADSEnabled then
		return false
	end
	return stat.ADSEnabled[sightIndex] and true or false
end

function WepState.Reset(self: WeaponState)
	self.RecoilUp:configure(RECOIL_SPRING)
	self.RecoilPos:configure(RECOIL_SPRING)
	self.RecoilDir:configure(RECOIL_SPRING)
	self.CameraSpring:configure(CAMERA_SPRING)
	
	self.RecoilRot:setPosition(0)
	self.RecoilCF = CFrame.new()
	self.RecoilFactor = 0
	self.Spread = 0

	self.wepStats(nil)
	self.gunModel(nil)
	self.gunAmmo = nil
	self.equipped(false)

	self.localAmmo(0)
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
