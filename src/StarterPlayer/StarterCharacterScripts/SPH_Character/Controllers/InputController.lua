local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(script.Parent.Parent.Enums)
local Intents = Enums.Intents
local config = require(ReplicatedStorage:WaitForChild("SPH_Assets").GameConfig)

local InputController = {}

InputController._callbacks = {}


-- Callbacks to be assigned by the main CharacterClient
InputController.ActionFired = nil

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

local function InternalHandleInput(actionName, inputState, inputObject)
	if InputController.ActionFired then
		InputController.ActionFired(actionName, inputState, inputObject)
	end
end


function InputController.HandleInput(actionName, inputState, inputObject)
	if not InputController._callbacks[actionName] then
		warn(`[pearhead] no callback defined for intent key {actionName}`)
		return
	end
	InputController._callbacks[actionName](inputState, inputObject)
end

function InputController.BindInput(actionName, touchButton, priority, ...)
	local isValidIntent = false
	for _, intentName in pairs(Intents) do
		if intentName == actionName then
			isValidIntent = true
			break
		end
	end
	if not isValidIntent then
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
	ContextActionService:BindActionAtPriority("SPH_Trigger", InternalHandleInput, config.mobileButtons, config.gunInputPriority, unpack(config.fireGun))
	ContextActionService:BindActionAtPriority("SPH_DropGun", InternalHandleInput, false, config.gunInputPriority, unpack(config.dropKey))
	ContextActionService:BindActionAtPriority("SPH_Reload", InternalHandleInput, config.mobileButtons, config.gunInputPriority, unpack(config.keyReload))
	ContextActionService:BindActionAtPriority("SPH_Chamber", InternalHandleInput, false, config.gunInputPriority, unpack(config.keyChamber))
	ContextActionService:BindActionAtPriority("SPH_SwitchSights", InternalHandleInput, false, config.gunInputPriority, unpack(config.sightSwitch))
	InputController.BindInput(Intents.FREELOOK, false, config.gunInputPriority, unpack(config.freeLook))
	ContextActionService:BindActionAtPriority("SPH_HoldUp", InternalHandleInput, false, config.gunInputPriority, unpack(config.holdUp))
	ContextActionService:BindActionAtPriority("SPH_HoldPatrol", InternalHandleInput, false, config.gunInputPriority, unpack(config.holdPatrol))
	ContextActionService:BindActionAtPriority("SPH_HoldDown", InternalHandleInput, false, config.gunInputPriority, unpack(config.holdDown))
	ContextActionService:BindActionAtPriority("SPH_SwitchFireMode", InternalHandleInput, false, config.gunInputPriority, unpack(config.switchFireMode))
	ContextActionService:BindActionAtPriority("SPH_ToggleLaser", InternalHandleInput, false, config.gunInputPriority, unpack(config.toggleLaser))
	ContextActionService:BindActionAtPriority("SPH_ToggleFlashlight", InternalHandleInput, false, config.gunInputPriority, unpack(config.toggleFlashlight))

	if isFirstPerson then
		InputController.BindAiming()
	end

	ContextActionService:SetTitle("SPH_Trigger", "Fire")
	ContextActionService:SetPosition("SPH_Trigger", UDim2.fromScale(0.3, 0.6))

	ContextActionService:SetTitle("SPH_Reload", "Reload")
	ContextActionService:SetPosition("SPH_Reload", UDim2.fromScale(0, 0.6))
end

function InputController.UnbindGunInputs()
	ContextActionService:UnbindAction("SPH_Trigger")
	ContextActionService:UnbindAction("SPH_DropGun")
	ContextActionService:UnbindAction("SPH_Reload")
	InputController.UnbindInput(Intents.HOLD_AIM)
	ContextActionService:UnbindAction("SPH_Chamber")
	ContextActionService:UnbindAction("SPH_SwitchSights")
	InputController.UnbindInput(Intents.FREELOOK)
	ContextActionService:UnbindAction("SPH_HoldUp")
	ContextActionService:UnbindAction("SPH_HoldPatrol")
	ContextActionService:UnbindAction("SPH_HoldDown")
	ContextActionService:UnbindAction("SPH_SwitchFireMode")
	ContextActionService:UnbindAction("SPH_ToggleLaser")
	ContextActionService:UnbindAction("SPH_ToggleFlashlight")
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