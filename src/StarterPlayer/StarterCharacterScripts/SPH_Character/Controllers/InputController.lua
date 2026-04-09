local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(script.Parent.Parent.Enums)
local Intents = Enums.Intents
local config = require(ReplicatedStorage:WaitForChild("SPH_Assets").GameConfig)

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

function InputController.BindAiming()
	InputController.BindInput(Intents.HOLD_AIM, config.mobileButtons, config.gunInputPriority, unpack(config.aimGun))
	ContextActionService:SetTitle(Intents.HOLD_AIM, "Aim")
	ContextActionService:SetPosition(Intents.HOLD_AIM, UDim2.fromScale(0.24, 0.3))
end

function InputController.UnbindAiming()
	InputController.UnbindInput(Intents.HOLD_AIM)
end

function InputController.BindGunInputs(isFirstPerson)
	InputController
		.BindInput(Intents.TRIGGER, config.mobileButtons, config.gunInputPriority, unpack(config.fireGun))
		.BindInput(Intents.DROP_GUN, false, config.gunInputPriority, unpack(config.dropKey))
		.BindInput(Intents.RELOAD, config.mobileButtons, config.gunInputPriority, unpack(config.keyReload))
		.BindInput(Intents.CHAMBER, false, config.gunInputPriority, unpack(config.keyChamber))
		.BindInput(Intents.SWITCH_SIGHTS, false, config.gunInputPriority, unpack(config.sightSwitch))
		.BindInput(Intents.FREELOOK, false, config.gunInputPriority, unpack(config.freeLook))

		.BindInput(Intents.SWITCH_FIRE_MODE, false, config.gunInputPriority, unpack(config.switchFireMode))
		.BindInput(Intents.TOGGLE_LASER, false, config.gunInputPriority, unpack(config.toggleLaser))
		.BindInput(Intents.TOGGLE_FLASHLIGHT, false, config.gunInputPriority, unpack(config.toggleFlashlight))

	if isFirstPerson then
		InputController.BindAiming()
	end

	ContextActionService:SetTitle(Intents.TRIGGER, "Fire")
	ContextActionService:SetPosition(Intents.TRIGGER, UDim2.fromScale(0.3, 0.6))

	ContextActionService:SetTitle(Intents.RELOAD, "Reload")
	ContextActionService:SetPosition(Intents.RELOAD, UDim2.fromScale(0, 0.6))
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

function InputController.BindCharacterInputs()
	InputController
		.BindInput(Intents.LEAN_LEFT, false, config.movementInputPriority, unpack(config.leanLeft))
		.BindInput(Intents.LEAN_RIGHT, false, config.movementInputPriority, unpack(config.leanRight))
		.BindInput(Intents.SPRINT, false, config.movementInputPriority, unpack(config.keySprint))
		.BindInput(Intents.STANCE_DOWN, false, config.movementInputPriority, unpack(config.lowerStance))
		.BindInput(Intents.STANCE_UP, false, config.movementInputPriority, unpack(config.raiseStance))
end

function InputController.UnbindCharacterInputs()
	InputController.UnbindInput(
		Intents.LEAN_LEFT,
		Intents.LEAN_RIGHT,
		Intents.SPRINT,
		Intents.STANCE_DOWN,
		Intents.STANCE_UP)
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