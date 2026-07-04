local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Maid = require("@game/ReplicatedStorage/Packages/maid")

local create = Vide.create
local useAtom = require("@game/ReplicatedStorage/Packages/vide-charm").useAtom

local Consts = require("@game/ReplicatedStorage/Systems/Weapon/Core/Consts")
local CharacterStateModule = require("@game/ReplicatedStorage/Systems/Weapon/State/CharacterState")
local WeaponStateModule = require("@game/ReplicatedStorage/Systems/Weapon/State/WeaponState")
local EffectManager = require("@game/ReplicatedStorage/Systems/Weapon/UI/Logic/EffectManager")
local EffectUI = require("@game/ReplicatedStorage/Systems/Weapon/UI/Roots/EffectUI")
local Access = require("@game/ReplicatedStorage/Systems/Weapon/Access")
local Types = require("@game/ReplicatedStorage/Systems/Weapon/Core/ConfigurationTypes")
local DamageLogic = require("@game/ReplicatedStorage/Systems/Weapon/Combat/DamageLogic")
local HitmarkerTypes = require("@game/ReplicatedStorage/Systems/Weapon/UI/Configs/HitmarkerTypes")
local NetworkEvents = require("@game/ReplicatedStorage/Systems/Weapon/Network/NetworkEvents")
local NetworkSchemas = require("@game/ReplicatedStorage/Systems/Weapon/Network/NetworkSchemas")
local P = NetworkEvents.packets
local LocalEvents = require(script.Parent:WaitForChild("LocalEvents"))
local Player = Players.LocalPlayer

local EffectController = {}
EffectController.__index = EffectController

type self = {
	state: CharacterStateModule.CharacterState,
	weaponState: WeaponStateModule.WeaponState,
	effectManager: EffectManager.EffectManager,
	panelPositionSource: Vide.source<UDim2>,
	
	maid: Maid.Maid,

	_colorCorrection: ColorCorrectionEffect,
	_blur: BlurEffect,
	_blurTween: Tween?,
	_lastSuppressionTick: number,
	_lastAimPunchTick: number,
	_canBeSuppressed: Charm.Getter<boolean>,
}

export type EffectController = typeof(setmetatable({} :: self, EffectController))

local WHIZ_SOUNDS = {
"189916243",
"189916269",
"4927234432",
"4927234734",
"4927235094",
"4927236859",
"5303772965",}


function EffectController.new(params: {
	state: CharacterStateModule.CharacterState,
	weaponState: WeaponStateModule.WeaponState,
	effectManager: EffectManager.EffectManager,
}): EffectController
	local self = setmetatable({
		state = params.state,
		weaponState = params.weaponState,
		effectManager = params.effectManager,
		panelPositionSource = nil :: Vide.source<UDim2>,
		maid = Maid.new(),
		_lastSuppressionTick = tick(),
		_lastAimPunchTick = tick(),
	} :: self, EffectController)

	self.panelPositionSource = Vide.source(self:GetForwardPanelPosition())
	
	self._colorCorrection = game.Lighting:FindFirstChild("SuppressionColorCorrection")

	if not self._colorCorrection then
		self._colorCorrection = Instance.new("ColorCorrectionEffect", game.Lighting)
		self._colorCorrection.Name = "SuppressionColorCorrection"
	end

	self._blur = game.Lighting:FindFirstChild("SuppressionBlur") :: BlurEffect?
	if not self._blur then
		self._blur = Instance.new("BlurEffect", game.Lighting)
		self._blur.Name = "SuppressionBlur"
		self._blur.Size = 0
	end

	self._canBeSuppressed = Charm.computed(function()
		local seat = self.state.seat()
		local seatIsImmune = seat and (seat:HasTag(Consts.SUPPRESS_IMMUNE_SEAT) or seat:IsA("VehicleSeat"))

		return not seatIsImmune
	end)

	self.maid:GiveTask(Charm.subscribe(self.state.suppressionFactor, function(value, oldValue)
		self:SyncSuppressionFactor(value, oldValue)
	end))

	self.maid:GiveTask(Charm.effect(function()
		self._colorCorrection.Saturation = -self.state.suppressionFactor() * 0.4
	end))

	self.maid:GiveTask(Vide.mount(function()
		return create "ScreenGui" {
			Name = "SPH_Effects",
			IgnoreGuiInset = true,
			DisplayOrder = 100,
			ResetOnSpawn = true,

			EffectUI({
				activeDamage = self.effectManager.activeDamage,
				activeHitmarkers = self.effectManager.activeHitmarkers,
				suppressionFactor = useAtom(self.state.suppressionFactor),
				panelPosition = self.panelPositionSource,
				suppressionLimit = Access.config.suppressionVignetteLimit,
			}),
		}
	end, Player.PlayerGui))

	return self
end

function EffectController.Wire(self: EffectController, events: LocalEvents.LocalEvents)

	self.maid:GiveTask(events.BulletHit:Connect(function(...)
		self:OnBulletHit(...)
	end))

	self.maid:GiveTask(P.ReportSuppression.listen(function(data, _serverPlayer)
		self:OnReportSuppression(data)
	end))

	return self
end

function EffectController.OnReportSuppression(self: EffectController, data: NetworkSchemas.ReportSuppressionPayload)
	if not self._canBeSuppressed() then
		return
	end

	if tick() - self._lastSuppressionTick < Access.config.suppressionThrottle then
		return
	end
	self._lastSuppressionTick = tick()
	self.effectManager:PushSuppression(data.level, data.factor, data.limit)
end

function EffectController.OnBulletHit(self: EffectController, wepStats: Types.WeaponStats, bulletOrigin: Vector3, raycastResult: RaycastResult)
	if not raycastResult.Instance or not Access.config.hitmarkers then
		return
	end
	local zone = DamageLogic.getZone(raycastResult.Instance.Name)
	if zone == DamageLogic.Zones.None then
		return
	end

	local hitmarkerRegion = "Default"
	if zone == DamageLogic.Zones.Head then
		hitmarkerRegion = "Headshot"
	end
	local distance = (bulletOrigin - raycastResult.Position).Magnitude
	local hitmarkerInstance = HitmarkerTypes[hitmarkerRegion]()
	local estimatedDamage = DamageLogic.getDamage(wepStats.damage, raycastResult.Instance.Name, distance, wepStats.range)

	local screenPoint = workspace.CurrentCamera:WorldToViewportPoint(raycastResult.Position)
	hitmarkerInstance.Position(UDim2.fromOffset(screenPoint.X, screenPoint.Y))
	
	-- do the hitmarker stuff
	if Access.config.damageIndicators == "incremental" then
		self.effectManager:PushDamage(estimatedDamage)
	end

	if Access.config.hitmarkers then
		if Access.config.damageIndicators == "flash" then
			self.effectManager:PushHitmarker(hitmarkerInstance, raycastResult.Position, estimatedDamage)
		else
			self.effectManager:PushHitmarker(hitmarkerInstance, raycastResult.Position)--, estimatedDamage)
		end
	end

	local soundList = Access.assets.Sounds.Hitmarkers[hitmarkerRegion]:GetChildren() :: { Sound }
	local sound = soundList[math.random(#soundList)]
	SoundService:PlayLocalSound(sound)
end

function EffectController.ApplySuppressionAimPunch(self: EffectController, factor: number)
	if not Access.config.suppressionEffects or Access.config.suppressionAimPunchFactor <= 0 then
		return
	end

	local punchScale = Access.config.suppressionAimPunchFactor * 50 * factor
	local vr = punchScale * (0.75 + math.random() * 0.5) / 1000
	local hr = (math.random() - 0.5) * 2 * punchScale / 1000

	local kick = Vector3.new(vr, hr, 0)
	self.weaponState.CameraSpring.t = self.weaponState.CameraSpring.t + kick
	self.weaponState.CameraSpring.p = self.weaponState.CameraSpring.p + kick * 0.5
end

local function numLerp(a: number, b: number, t: number)
    return a + (b - a) * math.clamp(t, 0, 1)
end

function EffectController.SyncSuppressionFactor(self: EffectController, value: number, oldValue: number)
	local delta = value - oldValue
	if delta <= 0 then
		return
	end

	-- TEMP: play a whiz sound (this should be replaced later)
	local Som = Instance.new("Sound")
	Som.Parent = SoundService
	Som.SoundId = "rbxassetid://" .. WHIZ_SOUNDS[math.random(1, #WHIZ_SOUNDS)]
	Som.Volume = numLerp(1, 2.5, math.clamp(delta * 4, 0, 1))
	SoundService:PlayLocalSound(Som)
	game.Debris:AddItem(Som, Som.TimeLength)

	if tick() - self._lastAimPunchTick > Access.config.suppressionAimPunchThrottle then
		if self._blurTween then
			self._blurTween:Cancel()
			self._blurTween = nil
		end
		self._blur.Size = 15 * delta
		self._blurTween = TweenService:Create(self._blur, TweenInfo.new(0.5), { Size = 0 })
		self._blurTween:Play()

		self._lastAimPunchTick = tick()
		self:ApplySuppressionAimPunch(delta)
	end
end

function EffectController.GetForwardPanelPosition(self: EffectController): UDim2
	local gunModel = self.weaponState.gunModel()
	if not gunModel then
		return UDim2.fromScale(0.5, 0.5)
	end

	local muzzle = gunModel:FindFirstChild("Grip") and gunModel.Grip:FindFirstChild("Muzzle")
	if not muzzle then
		return UDim2.fromScale(0.5, 0.5)
	end

	local screenPoint = workspace.CurrentCamera:WorldToViewportPoint((muzzle.WorldCFrame * CFrame.new(0, 0, -50)).Position)
	return UDim2.fromOffset(screenPoint.X, screenPoint.Y)
end

function EffectController.UpdateHeartbeat(self: EffectController, _dt: number)
	self.panelPositionSource(self:GetForwardPanelPosition())
end

function EffectController.Destroy(self: EffectController)
	if self._blurTween then
		self._blurTween:Cancel()
	end
	if self._blur then
		self._blur.Size = 0
	end
	self.maid:DoCleaning()
end

return EffectController
