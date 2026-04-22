local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sph = require(ReplicatedStorage.SPH_Framework.GameAccess)
local Enums = require(sph.framework.Core.Enums)
local Intents = Enums.Intents
local config = sph.config

local InputController = {}

InputController._callbacks = {}

local function isValidIntent(actionName)
	for _, intentName in pairs(Intents) do
		if intentName == actionName then
			return true
		end
	end
	return false
end


function InputController.Initialize(args)
	for intentKey, _ in pairs(Intents) do
		local callback = args.callbacks[intentKey]
		if not callback then
			warn(`[pearhead] no callback defined for intent key {intentKey}`)
		end

		InputController._callbacks[intentKey] = callback or function(inputState, inputObject)
			warn(`[pearhead] no callback defined for intent key {intentKey}`)
		end
	end
end

function InputController.SetIntentCallback(actionName, callback)
	if not isValidIntent(actionName) then
		warn(`[pearhead] {actionName} isn't a valid intent in Enums.Intents`)
		return false
	end
	if type(callback) ~= "function" then
		warn(`[pearhead] callback for {actionName} must be a function`)
		return false
	end

	InputController._callbacks[actionName] = callback
	return true
end

function InputController.ClearIntentCallback(actionName)
	if not isValidIntent(actionName) then
		warn(`[pearhead] {actionName} isn't a valid intent in Enums.Intents`)
		return false
	end

	InputController._callbacks[actionName] = function(inputState, inputObject)
		warn(`[pearhead] no callback defined for intent key {actionName}`)
	end
	return true
end


function InputController.HandleInput(actionName, inputState, inputObject)
	if not InputController._callbacks[actionName] then
		warn(`[pearhead] no callback defined for intent key {actionName}`)
		return
	end
	InputController._callbacks[actionName](inputState, inputObject)
end

function InputController.BindInput(actionName, touchButton, priority, ...)
	if not isValidIntent(actionName) then
		warn(`[pearhead] {actionName} isn't a valid intent in Enums.Intents`)
	end
	ContextActionService:BindActionAtPriority(actionName, InputController.HandleInput,touchButton, priority, ...)
	return InputController
end

function InputController.UnbindInput(...)
	for _, actionName in ipairs({...}) do
		ContextActionService:UnbindAction(actionName)
	end
end

----------------------------------------------------------------------------------------------------------------

function InputController.BindGunInputs()
	InputController
		.BindInput(Intents.TRIGGER, false, config.gunInputPriority, unpack(config.fireGun))
		.BindInput(Intents.DROP_GUN, false, config.gunInputPriority, unpack(config.dropKey))
		.BindInput(Intents.RELOAD, false, config.gunInputPriority, unpack(config.keyReload))
		.BindInput(Intents.CHAMBER, false, config.gunInputPriority, unpack(config.keyChamber))
		.BindInput(Intents.SWITCH_SIGHTS, false, config.gunInputPriority, unpack(config.sightSwitch))
		.BindInput(Intents.FREELOOK, false, config.gunInputPriority, unpack(config.freeLook))
		.BindInput(Intents.HOLD_AIM, config.mobileButtons, config.gunInputPriority, unpack(config.aimGun))

		.BindInput(Intents.SWITCH_FIRE_MODE, false, config.gunInputPriority, unpack(config.switchFireMode))
		.BindInput(Intents.TOGGLE_LASER, false, config.gunInputPriority, unpack(config.toggleLaser))
		.BindInput(Intents.TOGGLE_FLASHLIGHT, false, config.gunInputPriority, unpack(config.toggleFlashlight))
end

function InputController.BindCharacterInputs()
	InputController
		.BindInput(Intents.LEAN_LEFT, false, config.movementInputPriority, unpack(config.leanLeft))
		.BindInput(Intents.LEAN_RIGHT, false, config.movementInputPriority, unpack(config.leanRight))
		.BindInput(Intents.SPRINT, false, config.movementInputPriority, unpack(config.keySprint))
		.BindInput(Intents.STANCE_DOWN, false, config.movementInputPriority, unpack(config.lowerStance))
		.BindInput(Intents.STANCE_UP, false, config.movementInputPriority, unpack(config.raiseStance))
end

function InputController.UnbindGunInputs()
	InputController.UnbindInput(
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

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		InputController._callbacks[Intents.SCROLL](input.Position.Z, UserInputService:IsKeyDown(config.holdForScrollZoom))
	end
end)

UserInputService.JumpRequest:Connect(function()
	InputController._callbacks[Intents.JUMP]()
end)

return InputController