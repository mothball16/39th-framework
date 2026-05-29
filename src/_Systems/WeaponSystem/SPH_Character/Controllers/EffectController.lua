local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Maid = require("@game/ReplicatedStorage/Packages/maid")

local create = Vide.create
local useAtom = require("@game/ReplicatedStorage/Packages/vide-charm").useAtom

local CharacterStateModule = require("@game/ReplicatedStorage/SPH_Framework/State/CharacterState")
local WeaponStateModule = require("@game/ReplicatedStorage/SPH_Framework/State/WeaponState")
local EffectManager = require("@game/ReplicatedStorage/SPH_Framework/UI/Logic/EffectManager")
local EffectUI = require("@game/ReplicatedStorage/SPH_Framework/UI/Roots/EffectUI")
local Access = require("@game/ReplicatedStorage/SPH_Framework/Access")
local Types = require("@game/ReplicatedStorage/SPH_Framework/Core/ConfigurationTypes")
local DamageLogic = require("@game/ReplicatedStorage/SPH_Framework/Combat/DamageLogic")
local HitmarkerTypes = require("@game/ReplicatedStorage/SPH_Framework/UI/Configs/HitmarkerTypes")
local EventsModule = require(script.Parent.Events)
local EffectController = {}
EffectController.__index = EffectController

type self = {
	state: CharacterStateModule.CharacterState,
	weaponState: WeaponStateModule.WeaponState,
	effectManager: EffectManager.EffectManager,
	panelPositionSource: Vide.source<UDim2>,
	
	maid: Maid.Maid,

	_colorCorrection: ColorCorrectionEffect,
	_lastSuppressionTick: number,
	_lastAimPunchTick: number,
}

export type EffectController = typeof(setmetatable({} :: self, EffectController))

local WHIZ_SOUNDS = {"342190005", "342190012", "342190017", "342190024"}


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

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	self.panelPositionSource = Vide.source(self:GetForwardPanelPosition())
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
	end, playerGui))

	self._colorCorrection = game.Lighting:FindFirstChild("SuppressionColorCorrection")

	if not self._colorCorrection then
		self._colorCorrection = Instance.new("ColorCorrectionEffect", game.Lighting)
		self._colorCorrection.Name = "SuppressionColorCorrection"
	end

	
	self.maid:GiveTask(Charm.subscribe(self.state.suppressionFactor, function(value, oldValue)
		self:SyncSuppressionFactor(value, oldValue)
	end))

	self.maid:GiveTask(Charm.effect(function()
		self._colorCorrection.Saturation = -self.state.suppressionFactor() * 0.4
	end))

	return self
end

function EffectController.Wire(self: EffectController, events: EventsModule.Events)
	local net = require("@game/ReplicatedStorage/SPH_Framework/Network/Events").GetNamespace()
	local P = net.packets

	self.maid:GiveTask(events.BulletHit:Connect(function(...)
		self:OnBulletHit(...)
	end))

	self.maid:GiveTask(P.ReportSuppression.listen(function(data, _serverPlayer)
		if tick() - self._lastSuppressionTick < Access.config.suppressionThrottle then
			return
		end

		-- TEMP: play a whiz sound (this should be replaced later)
		local Som = Instance.new("Sound")
		Som.Parent = Players.LocalPlayer.PlayerGui
		Som.SoundId = "rbxassetid://" .. WHIZ_SOUNDS[math.random(1, 4)]
		Som.Volume = 2
		Som.PlayOnRemove = true
		Som:Destroy()

		if tick() - self._lastAimPunchTick > Access.config.suppressionAimPunchThrottle then
			local tempBlur = Instance.new("BlurEffect", game.Lighting)
			tempBlur.Size = 15 * data.factor
			game.Debris:AddItem(tempBlur, 0.5)
			TweenService:Create(tempBlur, TweenInfo.new(0.5), { Size = 0 }):Play()

			self._lastAimPunchTick = tick()
			self:ApplySuppressionAimPunch(data.factor)
		end


		self._lastSuppressionTick = tick()
		self.effectManager:PushSuppression(data.level, data.factor)
	end))

	return self
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

	self.effectManager:PushHitmarker(hitmarkerInstance, raycastResult.Position)
	self.effectManager:PushDamage(estimatedDamage)

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

function EffectController.SyncSuppressionFactor(self: EffectController, value: number, oldValue: number)
	local delta = value - oldValue
	if delta > 0 then

	else

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
	print("destroying effect controller")
	self.maid:DoCleaning()
end

return EffectController
