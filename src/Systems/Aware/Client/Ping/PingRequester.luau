--!strict
--[[
evaluates ping targeting and sends create/remove requests to the server
does not know or care about PingTagRenderer
]]

local cam = workspace.CurrentCamera
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local Network = require("../Net/Network")
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Access = require("@game/ReplicatedStorage/Systems/Aware/Access")
local Config = Access.config
local UserSettings = require("../Core/UserSettings")

local PingRequester = {}

local function findViewportHitPosition(x: number, y: number, cast: number): (Vector3, boolean)
	local Ray = cam:ViewportPointToRay(x, y)

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { workspace.CurrentCamera }

	if localPlayer.Character then
		table.insert(Params.FilterDescendantsInstances, localPlayer.Character)
	end

	local Raycast = workspace:Raycast(Ray.Origin, Ray.Direction * cast, Params)
	return Raycast ~= nil and Raycast.Position or Ray.Origin + Ray.Direction * cast, Raycast ~= nil
end

local function posWithinDeadzone(position: Vector3, mouseLocation: Vector2): boolean
	local currentPingScreenPosition = cam:WorldToViewportPoint(position)
	currentPingScreenPosition = Vector2.new(currentPingScreenPosition.X, currentPingScreenPosition.Y)
	local deadzone = if UserSettings.UseDeadzone()
		then math.min(cam.ViewportSize.X, cam.ViewportSize.Y)
			* UserSettings.PingClearDeadzone() -- use viewport scale for deadzone
		else math.min(UserSettings.PingSize().X.Offset, UserSettings.PingSize().Y.Offset) / 2 -- guestimate it

	local distance = (currentPingScreenPosition - mouseLocation).Magnitude
	return distance < deadzone
end

-- determines if a ping should be created or deleted, and then requests to create or delete it accordingly
function PingRequester.EvaluatePing(currentPingPos: Vector3?, mouseLocation: Vector2)
	local screenHitPosition = findViewportHitPosition(mouseLocation.X, mouseLocation.Y, Config.PingMaxDistance)

	if currentPingPos and posWithinDeadzone(currentPingPos, mouseLocation) then
		Network.RequestRemovePing.Fire()
		return
	end

	Network.RequestPing.Fire({
		position = screenHitPosition,
	})
end

function PingRequester.EvaluateRemovePing(ownedPings: { [string]: Types.PingInfo }, mouseLocation: Vector2)
	-- check if we got any pings in the deadzone - if we do, then target that one for deletion and return early
	for category, ping in ownedPings do
		if not posWithinDeadzone(ping.position, mouseLocation) then
			continue
		end
		Network.RequestRemovePing.Fire()
		return
	end
end

return PingRequester
