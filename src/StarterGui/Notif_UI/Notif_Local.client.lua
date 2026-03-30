--[[       
INTERACTIVE SYSTEM
Notification Module
1.4.2

by Jarr (@SrJarr) aka jarr__
RELEASED FOR FREE - DRAGOON'S DEN
--]]

--// Services
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local player = players.LocalPlayer
local playerCam = workspace.CurrentCamera
local replicatedStorage = game:GetService("ReplicatedStorage")

--// Stuff
local assets = replicatedStorage.INTERACT_Assets
local hud = script.Parent.HUD
local pings = {}

--// Functions
local function SelectPing(ping)
	--Ping data
	local location = ping:GetAttribute("Ping_Location")
	local track = ping:FindFirstChild("Ping_Track")
	
	assets.Events.Notification:FireServer("SetTarget", location, track and track.Value)
end

local function UpdatePings()
	for ping, value in pings do
		if not ping or not ping.Parent then continue end
		
		--Ping data
		local location = ping:GetAttribute("Ping_Location")
		local track = ping:FindFirstChild("Ping_Track")
		--local creator = ping:GetAttribute("Ping_Creator")
		--local duration = ping:GetAttribute("Ping_Duration")
		--local time = ping:GetAttribute("Ping_Time")
		
		local finalPos = (track and track.Value and track.Value:GetPivot().Position) or location
		
		--Location
		local targetPos, targetVis = playerCam:WorldToScreenPoint(finalPos)
		ping.Position = UDim2.new(0, targetPos.X, 0, targetPos.Y)
		ping.Visible = targetVis
	end
end

local function AddPings(child:Frame)
	if child.Name ~= "LocationPing" then return end
	pings[child] = true
	
	local button = child:FindFirstChild("Button")
	local button2 = child:FindFirstChild("Ping_NotifRef").Value:FindFirstChild("Button")
	
	if button then
		button.Activated:Connect(function()
			SelectPing(child)
		end)
	end
	if button2 then
		button2.Activated:Connect(function()
			SelectPing(child)
		end)
	end
end

local function RemovePings(child:Frame)
	pings[child] = nil
end

--// Connections
hud.ChildAdded:Connect(AddPings)
hud.ChildRemoved:Connect(RemovePings)
runService.RenderStepped:Connect(UpdatePings)