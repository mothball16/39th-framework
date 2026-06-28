local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Access = require("@game/ReplicatedStorage/Aware_Framework/Access")
local Config = Access.config
local UserSettings = require("./UserSettings")
local Network = require("./Network")
local PingController = require("./PingController").new()

local localPlayer = Players.LocalPlayer
local cam = workspace.CurrentCamera

local function findViewportHitPosition(x, y, cast): (Vector3, boolean)
	local Ray = cam:ViewportPointToRay(x, y)
	
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Blacklist
	Params.FilterDescendantsInstances = {localPlayer.Character, game.Workspace.CurrentCamera}
	
	local Raycast = workspace:Raycast(Ray.Origin, Ray.Direction * cast, Params)
	local Hit = Raycast ~= nil
	return Hit and Raycast.Position or Ray.Origin + Ray.Direction * cast, Hit
end


local function pingWithinDeadzone(ping: Instance, mouseLocation: Vector2): boolean
    local currentPingScreenPosition = cam:WorldToViewportPoint(ping.Position)
    currentPingScreenPosition = Vector2.new(currentPingScreenPosition.X, currentPingScreenPosition.Y)
    local deadzone = if UserSettings.UseDeadzone() 
        then math.min(cam.ViewportSize.X, cam.ViewportSize.Y) * UserSettings.PingClearDeadzone() -- use viewport scale for deadzone
        else math.min(UserSettings.PingSize().X.Offset, UserSettings.PingSize().Y.Offset) / 2 -- guestimate it

    local distance = (currentPingScreenPosition - mouseLocation).Magnitude
    return distance < deadzone
end

-- determines if a ping should be created or deleted, and then creates or deletes it accordingly
local function evaluatePing()
    local mouseLocation = UIS:GetMouseLocation()
    local screenHitPosition = findViewportHitPosition(mouseLocation.X, mouseLocation.Y, Config.PingMaxDistance)
    local currentPing = PingController:GetPingTag(localPlayer)

    if currentPing and pingWithinDeadzone(currentPing, mouseLocation) then
        PingController:DeletePingTag(localPlayer)
        Network.RequestRemovePing.Fire()
        return
    end

    -- create a new ping here
    PingController:RegisterPingTag(localPlayer, screenHitPosition, {
        imageId = Config.PingImageId,
        name = localPlayer.DisplayName,
        size = UserSettings.PingSize,
    })
    Network.RequestPing.Fire({
        position = screenHitPosition,
    })
end

local function evaluateRemovePing()
    local pings = PingController:GetPingTags()
    local mouseLocation = UIS:GetMouseLocation()

    -- check if we got any pings in the deadzone - if we do, then target that one for deletion and return early
    for _, ping in pings do
        if not pingWithinDeadzone(ping, mouseLocation) then continue end
        PingController:DeletePingTag(ping.owner)
        if ping.owner == localPlayer then
            Network.RequestRemovePing.Fire()
        end
        return
    end

    -- no selected ping to delete, just delete everything
    PingController:DeleteAllPingTags()
    Network.RequestRemovePing.Fire()
end

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == UserSettings.PingKey() then
        evaluatePing()
    elseif input.KeyCode == UserSettings.ClearPingKey() then
        evaluateRemovePing()
    end
end)

Network.ReportPing.On(function(data)
    PingController:RegisterPingTag(data.owner, data.position, {
        imageId = Config.PingImageId,
        name = data.name,
        size = UserSettings.PingSize,
    })
end)

Network.ReportRemovePing.On(function(data)
    PingController:DeletePingTag(data.owner)
end)