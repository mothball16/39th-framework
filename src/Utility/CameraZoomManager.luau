--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraZoomManager = {}

export type Getter = () -> number?

export type Targets = {
	fieldOfView: Getter?,
	fieldOfViewLerpSpeed: Getter?,
	maxZoomDistance: Getter?,
	mouseDeltaSensitivity: Getter?,
	[string]: Getter?, -- silence stupid luau errors (i want to go to rbxts...)
}

export type Values = {
	fieldOfView: number?,
	fieldOfViewLerpSpeed: number?,
	maxZoomDistance: number?,
	mouseDeltaSensitivity: number?,
}

type Registration = {
	priority: number,
	order: number,
	targets: Targets,
}

type Property = "fieldOfView" | "maxZoomDistance" | "mouseDeltaSensitivity"

local registrations = {} :: { [string]: Registration }
local registrationOrder = 0

function CameraZoomManager.Register(id: string, priority: number, targets: Targets): () -> ()
	-- Replace same id: manager is player-lifetime; owners like Weapon are character-scoped and re-register on respawn.
	registrationOrder += 1
	local registration: Registration = {
		priority = priority,
		order = registrationOrder,
		targets = targets,
	}
	registrations[id] = registration

	return function()
		if registrations[id] == registration then
			registrations[id] = nil
		end
	end
end

local function resolve(property: Property): (number?, Registration?)
	local winner: Registration? = nil
	local value: number? = nil

	for _, registration in registrations do
		local target = registration.targets[property]
		if not target then
			continue
		end

		local targetValue = target()
		if targetValue == nil then
			continue
		end

		if
			not winner
			or registration.priority > winner.priority
			or (registration.priority == winner.priority and registration.order < winner.order)
		then
			winner = registration
			value = targetValue
		end
	end

	return value, winner
end

function CameraZoomManager.Resolve(): Values
	local fieldOfView, fieldOfViewRegistration = resolve("fieldOfView")
	local maxZoomDistance = resolve("maxZoomDistance")
	local mouseDeltaSensitivity = resolve("mouseDeltaSensitivity")
	local fieldOfViewLerpSpeed
	if fieldOfViewRegistration and fieldOfViewRegistration.targets.fieldOfViewLerpSpeed then
		fieldOfViewLerpSpeed = fieldOfViewRegistration.targets.fieldOfViewLerpSpeed()
	end

	return {
		fieldOfView = fieldOfView,
		fieldOfViewLerpSpeed = fieldOfViewLerpSpeed,
		maxZoomDistance = maxZoomDistance,
		mouseDeltaSensitivity = mouseDeltaSensitivity,
	}
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer
	if not camera or not player then
		return
	end

	local target = CameraZoomManager.Resolve()
	if target.mouseDeltaSensitivity ~= nil then
		UserInputService.MouseDeltaSensitivity = target.mouseDeltaSensitivity
	end

	if target.fieldOfView ~= nil then
		local lerpFactor = if target.fieldOfViewLerpSpeed ~= nil then target.fieldOfViewLerpSpeed * dt else 1
		camera.FieldOfView = camera.FieldOfView + (target.fieldOfView - camera.FieldOfView) * lerpFactor
	end

	if target.maxZoomDistance ~= nil then
		player.CameraMaxZoomDistance = target.maxZoomDistance
	end
end

if RunService:IsClient() then
	RunService.RenderStepped:Connect(update)
end

return CameraZoomManager
