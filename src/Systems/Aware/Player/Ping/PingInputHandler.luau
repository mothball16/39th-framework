--!strict

local cam = workspace.CurrentCamera
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local PingController = require("./PingController")
local Network = require("../Net/Network")
local Access = require("@game/ReplicatedStorage/Systems/Aware/Access")
local Config = Access.config
local UserSettings = require("../Core/UserSettings")

local PingInputHandler = {}

local function findViewportHitPosition(x: number, y: number, cast: number): (Vector3, boolean)
	local Ray = cam:ViewportPointToRay(x, y)
	
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {workspace.CurrentCamera}
	
    if localPlayer.Character then
        table.insert(Params.FilterDescendantsInstances, localPlayer.Character)
    end

	local Raycast = workspace:Raycast(Ray.Origin, Ray.Direction * cast, Params)
	return Raycast ~= nil and Raycast.Position or Ray.Origin + Ray.Direction * cast,  Raycast ~= nil
end

local function isPingWithinDeadzone(ping: BasePart, mouseLocation: Vector2): boolean
    local currentPingScreenPosition = cam:WorldToViewportPoint(ping.Position)
    currentPingScreenPosition = Vector2.new(currentPingScreenPosition.X, currentPingScreenPosition.Y)
    local deadzone = if UserSettings.UseDeadzone() 
        then math.min(cam.ViewportSize.X, cam.ViewportSize.Y) * UserSettings.PingClearDeadzone() -- use viewport scale for deadzone
        else math.min(UserSettings.PingSize().X.Offset, UserSettings.PingSize().Y.Offset) / 2 -- guestimate it

    local distance = (currentPingScreenPosition - mouseLocation).Magnitude
    return distance < deadzone
end

-- determines if a ping should be created or deleted, and then creates or deletes it accordingly
function PingInputHandler.EvaluatePing(mouseLocation: Vector2)
    local screenHitPosition = findViewportHitPosition(mouseLocation.X, mouseLocation.Y, Config.PingMaxDistance)
    local currentPing = PingController.GetPingTag(localPlayer)

    if currentPing and currentPing.instance and isPingWithinDeadzone(currentPing.instance, mouseLocation) then
        PingController.DeletePingTag(localPlayer)
        Network.RequestRemovePing.Fire()
        return
    end

    -- create a new ping here
    PingController.RegisterPingTag(localPlayer, screenHitPosition, {
        imageId = Config.PingImageId,
        name = localPlayer.DisplayName,
        size = UserSettings.PingSize,
    })
    Network.RequestPing.Fire({
        position = screenHitPosition,
    })
end

function PingInputHandler.EvaluateRemovePing(mouseLocation: Vector2)
    local pings = PingController.GetPingTags()

    -- check if we got any pings in the deadzone - if we do, then target that one for deletion and return early
    for owner, ping in pings do
        if not isPingWithinDeadzone(ping.instance, mouseLocation) then continue end
        
        PingController.DeletePingTag(owner)
        if owner == localPlayer then
            Network.RequestRemovePing.Fire()
        end
        return
    end

    -- no selected ping to delete, just delete everything
    PingController.DeleteAllPingTags()
    Network.RequestRemovePing.Fire()
end

return PingInputHandler