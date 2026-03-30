--[[       
INTERACTIVE SYSTEM
Notifications Module
1.4.3

by Jarr (@SrJarr) aka jarr__
RELEASED FOR FREE - DRAGOON'S DEN
--]]

--// Services
local players = game:GetService("Players")
local DS = game:GetService("Debris")
local assets = game.ReplicatedStorage.INTERACT_Assets
local NotifMod = {}

local tgtMod = require(assets.Modules.TargetingSystem)

NotifMod.MaxPings = 9 --How many pings at a time?

--// Functions
local function NotifPlayer(Player:Player, field:string, duration:number, text:string, class:string?, sound:string?, notifType:string?)
	local fieldFind = Player.PlayerGui.Notif_UI:FindFirstChild(field)
	if not fieldFind then error("NotifModule: Invalid Field") return end

	local sampleNotif = script:FindFirstChild(notifType or "Sample_Notif1")
	local newNotif

	local repeatNotif = class and fieldFind:FindFirstChild(class)
	if repeatNotif then
		newNotif = repeatNotif:Clone()
		newNotif:SetAttribute("Notification_Stack", repeatNotif:GetAttribute("Notification_Stack")+1)
		newNotif.Count.Text = "x"..newNotif:GetAttribute("Notification_Stack")
		repeatNotif:Destroy()

		--color gradient
		if newNotif:GetAttribute("Notification_Stack")>10 then
			newNotif.Count.TextColor3 = Color3.fromRGB(255, 0, 0)
		elseif newNotif:GetAttribute("Notification_Stack")>4 then
			newNotif.Count.TextColor3 = Color3.fromRGB(255, 115, 0)
		elseif newNotif:GetAttribute("Notification_Stack")>2 then
			newNotif.Count.TextColor3 = Color3.fromRGB(255, 200, 0)
		end

		newNotif.Text = text
		newNotif.Parent = fieldFind
		DS:AddItem(newNotif, duration)
	else
		newNotif = sampleNotif:Clone()
		newNotif.Name = class or field
		newNotif:SetAttribute("Notification_Class", class)
		newNotif.Text = text
		newNotif.Parent = fieldFind
		DS:AddItem(newNotif, duration)
	end

	local soundFind = sound and Player.PlayerGui.Notif_UI.SoundGroup:FindFirstChild(sound)
	if soundFind then
		soundFind:Play()
	end	
	return newNotif
end

local function PingOverflow(hud:Frame)
	local pings = hud:GetChildren()
	local oldestTime = 999999
	local oldestPing 
	
	for _, ping in pings do
		if not ping:IsA("Frame") then continue end
		
		local pingTime = ping:GetAttribute("Ping_Time")
		if not pingTime then continue end
		
		if pingTime < oldestTime then
			oldestTime = pingTime
			oldestPing = ping
		end
	end
	
	if #pings >= NotifMod.MaxPings and oldestPing then 
		local pingNotif = oldestPing:FindFirstChild("Ping_NotifRef")
		if pingNotif and pingNotif.Value then pingNotif.Value:Destroy() end
		oldestPing:Destroy() 
	end
end

function NotifMod.Initialize()
	assets.Events.Notification.OnServerEvent:Connect(function(player, func:string, ...)
		if func=="SetTarget" then
			tgtMod.SetTargetData(player, ...)
			
			local notifText = [[<b><font color="#]]..Color3.fromRGB(130, 255, 62):ToHex()..[[">Target Data Updated!</font></b>]]
			NotifPlayer(player, "LowerMid", 5, notifText)
		end
	end)
end

function NotifMod.Notificate(Player:Player, Everyone:boolean, ...)
	if Player and not Everyone then
		NotifPlayer(Player, ...)
	elseif Everyone then
		for _, plr in players:GetPlayers() do
			NotifPlayer(plr, ...)
		end
	end
end

function NotifMod.PingLocation(Player:Player, creator:number, location:Vector3, instance:Instance?, duration:number, sound:string?, pingColor, pingId, datalinked)
	if not Player or not location then return end
	local creatorPlayer = players:GetPlayerByUserId(creator)
	if not creatorPlayer then return end
	
	local overflow = PingOverflow(Player.PlayerGui.Notif_UI.HUD)
	if overflow then return end
	
	if not pingColor then
		pingColor = Color3.fromRGB(math.random(1, 25)*10, math.random(1, 25)*10, math.random(1, 25)*10)
	end
	if not pingId then
		pingId = ""
	end
	
	local notifText1 = [[<b>]]..Player.Name..[[: <font color="#]]..pingColor:ToHex()..[[">]]..tgtMod.VectorToString(location)..[[</font></b>]]
	local notifText2 = [[<b>]]..Player.Name..[[: <font color="#]]..pingColor:ToHex()..[[">]].."Target"..[[</font></b>]]
	local notifObj = NotifPlayer(Player, "UpperMid", duration, datalinked and notifText1 or notifText2, nil, nil, "Sample_Notif2")
	
	local locationPing = script.Sample_LocationPing:Clone()
	locationPing.Name = "LocationPing"
	locationPing.BackgroundColor3 = pingColor
	locationPing.UIStroke.Color = pingColor:Lerp(Color3.fromRGB(255, 255, 255), 0.5)
	locationPing.TextLabel.TextStrokeColor3 = pingColor
	locationPing.NumberLabel.Text = pingId
	locationPing:SetAttribute("Ping_ID", pingId)
	locationPing:SetAttribute("Ping_Creator", creator)
	locationPing:SetAttribute("Ping_Duration", duration)
	locationPing:SetAttribute("Ping_Time", os.clock())
	locationPing:SetAttribute("Ping_Location", location)
	
	local locationButton = locationPing.Button
	local locationButton2 = notifObj.Button
	if not datalinked and locationButton and locationButton2 then 
		locationButton:Destroy() 
		locationButton2:Destroy() 
	end
	
	local notifRef = Instance.new("ObjectValue")
	notifRef.Name = "Ping_NotifRef"
	notifRef.Parent = locationPing
	notifRef.Value = notifObj
	
	if instance then
		local locationTrack = Instance.new("ObjectValue")
		locationTrack.Name = "Ping_Track"
		locationTrack.Parent = locationPing
		locationTrack.Value = instance
	end
	
	locationPing.Parent = Player.PlayerGui.Notif_UI.HUD
	DS:AddItem(locationPing, duration)
	
	local soundFind = sound and Player.PlayerGui.Notif_UI.SoundGroup:FindFirstChild(sound)
	if soundFind then
		soundFind:Play()
	end	
end

return NotifMod
