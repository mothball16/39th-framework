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
InputController.ScrollFired = nil
InputController.JumpRequested = nil

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
	if not Intents[actionName] then
		warn(`[pearhead] {actionName} isn't a valid intent in Enums.Intents`)
	end
	ContextActionService:BindActionAtPriority(actionName, InputController.HandleInput,touchButton, priority, ...)
	return InputController
end

function InputController.UnbindInput(...)
	for _, actionName in ipairs(...) do
		ContextActionService:UnbindAction(actionName)
	end
end

function InputController.BindAiming()
	ContextActionService:BindActionAtPriority("SPH_HoldAim", InternalHandleInput, config.mobileButtons, config.gunInputPriority, unpack(config.aimGun))
	ContextActionService:SetTitle("SPH_HoldAim", "Aim")
	ContextActionService:SetPosition("SPH_HoldAim", UDim2.fromScale(0.24, 0.3))
end

function InputController.UnbindAiming()
	ContextActionService:UnbindAction("SPH_HoldAim")
end

function InputController.BindGunInputs(isFirstPerson)
	ContextActionService:BindActionAtPriority("SPH_Trigger", InternalHandleInput, config.mobileButtons, config.gunInputPriority, unpack(config.fireGun))
	ContextActionService:BindActionAtPriority("SPH_DropGun", InternalHandleInput, false, config.gunInputPriority, unpack(config.dropKey))
	ContextActionService:BindActionAtPriority("SPH_Reload", InternalHandleInput, config.mobileButtons, config.gunInputPriority, unpack(config.keyReload))
	ContextActionService:BindActionAtPriority("SPH_Chamber", InternalHandleInput, false, config.gunInputPriority, unpack(config.keyChamber))
	ContextActionService:BindActionAtPriority("SPH_SwitchSights", InternalHandleInput, false, config.gunInputPriority, unpack(config.sightSwitch))
	ContextActionService:BindActionAtPriority("SPH_Freelook", InternalHandleInput, false, config.gunInputPriority, unpack(config.freeLook))
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
	ContextActionService:UnbindAction("SPH_HoldAim")
	ContextActionService:UnbindAction("SPH_Chamber")
	ContextActionService:UnbindAction("SPH_SwitchSights")
	ContextActionService:UnbindAction("SPH_Freelook")
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
		if InputController.ScrollFired then
			InputController.ScrollFired(input.Position.Z, UserInputService:IsKeyDown(config.holdForScrollZoom))
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	if InputController.JumpRequested then
		InputController.JumpRequested()
	end
end)

return InputController