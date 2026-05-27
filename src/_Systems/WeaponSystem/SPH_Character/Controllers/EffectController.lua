local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local create = Vide.create
local useAtom = require(Packages["vide-charm"]).useAtom
local Maid = require(Packages.maid)

local Framework = ReplicatedStorage.SPH_Framework
local CharacterStateModule = require(Framework.State.CharacterState)
local WeaponStateModule = require(Framework.State.WeaponState)
local EffectManager = require(Framework.UI.Logic.EffectManager)
local EffectUI = require(Framework.UI.Roots.EffectUI)

local EffectController = {}
EffectController.__index = EffectController

type self = {
	state: CharacterStateModule.CharacterState,
	weaponState: WeaponStateModule.WeaponState,
	effectManager: EffectManager.EffectManager,
	panelPositionSource: Vide.source<UDim2>,
	maid: Maid.Maid,
}

export type EffectController = typeof(setmetatable({} :: self, EffectController))

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
	} :: self, EffectController)

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	self.panelPositionSource = Vide.source(self:GetMuzzleScreenPosition())
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
			}),
		}
	end, playerGui))

	return self
end

function EffectController.GetMuzzleScreenPosition(self: EffectController): UDim2
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
	self.panelPositionSource(self:GetMuzzleScreenPosition())
end

function EffectController.Destroy(self: EffectController)
	self.maid:DoCleaning()
end

return EffectController
