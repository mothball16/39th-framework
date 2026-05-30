local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = ReplicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local Enums = require(Framework.Core.Enums)
local Intents = Enums.Intents
local config = Access.config

local InputController = {}
InputController.__index = InputController

type self = {
	callbacks: { [string]: (...any) -> () },
}

export type InputController = typeof(setmetatable({} :: self, InputController))

local function isValidIntent(actionName: string): boolean
	for _, intentName in pairs(Intents) do
		if intentName == actionName then
			return true
		end
	end
	return false
end

function InputController.new(params: {
	callbacks: { [string]: (...any) -> () },
}): InputController
	local self = setmetatable({
		callbacks = params.callbacks,
	} :: self, InputController)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self.callbacks[Intents.SCROLL](input.Position.Z, UserInputService:IsKeyDown(config.holdForScrollZoom))
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		self.callbacks[Intents.JUMP]()
	end)

	return self
end

function InputController.SetIntentCallback(self: InputController, actionName: string, callback: (...any) -> ())
	if not isValidIntent(actionName) then
		warn(`[pearhead] {actionName} isn't a valid intent in Enums.Intents`)
		return false
	end
	if type(callback) ~= "function" then
		warn(`[pearhead] callback for {actionName} must be a function`)
		return false
	end

	self.callbacks[actionName] = callback
	return true
end

function InputController.ClearIntentCallback(self: InputController, actionName: string): boolean
	if not isValidIntent(actionName) then
		warn(`[pearhead] {actionName} isn't a valid intent in Enums.Intents`)
		return false
	end

	self.callbacks[actionName] = nil
	return true
end

function InputController.HandleInput(self: InputController, actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
	local callback = self.callbacks[actionName]
	if not callback then
		warn(`[pearhead] no callback defined for intent key {actionName}`)
		return
	end
	callback(inputState, inputObject)
end

function InputController.BindInput(self: InputController, actionName: string, touchButton: boolean, priority: number, ...): InputController
	if not isValidIntent(actionName) then
		warn(`[pearhead] {actionName} isn't a valid intent in Enums.Intents`)
	end
	ContextActionService:BindActionAtPriority(actionName, function(name, state, obj)
		self:HandleInput(name, state, obj)
	end, touchButton, priority, ...)
	return self
end

function InputController.UnbindInput(self: InputController, ...)
	for _, name in ipairs({ ... }) do
		ContextActionService:UnbindAction(name)
	end
end

function InputController.BindGunInputs(self: InputController)
	self
		:BindInput(Intents.TRIGGER, false, config.gunInputPriority, unpack(config.fireGun))
		:BindInput(Intents.DROP_GUN, false, config.gunInputPriority, unpack(config.dropKey))
		:BindInput(Intents.RELOAD, false, config.gunInputPriority, unpack(config.keyReload))
		:BindInput(Intents.CHAMBER, false, config.gunInputPriority, unpack(config.keyChamber))
		:BindInput(Intents.SWITCH_SIGHTS, false, config.gunInputPriority, unpack(config.sightSwitch))
		:BindInput(Intents.FREELOOK, false, config.gunInputPriority, unpack(config.freeLook))
		:BindInput(Intents.HOLD_AIM, config.mobileButtons, config.gunInputPriority, unpack(config.aimGun))
		:BindInput(Intents.SWITCH_FIRE_MODE, false, config.gunInputPriority, unpack(config.switchFireMode))
		:BindInput(Intents.TOGGLE_LASER, false, config.gunInputPriority, unpack(config.toggleLaser))
		:BindInput(Intents.TOGGLE_FLASHLIGHT, false, config.gunInputPriority, unpack(config.toggleFlashlight))
end

function InputController.BindCharacterInputs(self: InputController)
	self
		:BindInput(Intents.LEAN_LEFT, false, config.movementInputPriority, unpack(config.leanLeft))
		:BindInput(Intents.LEAN_RIGHT, false, config.movementInputPriority, unpack(config.leanRight))
		:BindInput(Intents.SPRINT, false, config.movementInputPriority, unpack(config.keySprint))
		:BindInput(Intents.STANCE_DOWN, false, config.movementInputPriority, unpack(config.lowerStance))
		:BindInput(Intents.STANCE_UP, false, config.movementInputPriority, unpack(config.raiseStance))
end

function InputController.UnbindGunInputs(self: InputController)
	self:UnbindInput(
		Intents.TRIGGER,
		Intents.DROP_GUN,
		Intents.RELOAD,
		Intents.HOLD_AIM,
		Intents.CHAMBER,
		Intents.SWITCH_SIGHTS,
		Intents.FREELOOK,
		Intents.HOLD_UP,
		Intents.HOLD_PATROL,
		Intents.HOLD_DOWN,
		Intents.SWITCH_FIRE_MODE,
		Intents.TOGGLE_LASER,
		Intents.TOGGLE_FLASHLIGHT
	)
end

return InputController
