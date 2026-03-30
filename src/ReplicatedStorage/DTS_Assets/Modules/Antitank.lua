--[[       
DRAGOON TANK SYSTEM
Antitank functionality
1.2.0
--]]

--[[
HOW ARMOR WORKS:
There is a health value contained in each vehicle with the tag "Dragoon_Vehicle".
Any part tagged "Dragoon_Armor" inside this vehicle will react to damage.

Armor parts can have 2 attributes. "Armor_Thickness" and "Armor_DmgMult"
Armor Thickness is usually in MM. If the projectile has a greater penetration value than the armor thickness, it will damage the vehicle.
If not, it might fail or bounce off the armor.
Armor_DmgMult (Damage multiplier) multiplies the damage of the projectile IF it penetrates first. This is useful for engine blocks or critical parts
that might heavily damage a vehicle. Of course, this attribute is optional.
--]]

--// Services
local DS = game:GetService("Debris")
local players = game:GetService("Players")
local debris = game:GetService("Debris")
local collection = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local atmod = {}

--// Folders
local assets = replicatedStorage.DTS_Assets
local modules = assets.Modules
local wmodules = assets.Weapons
local amodules = assets.Addons
local fx = assets.FX
local projectiles = assets.Projectiles

local config = require(assets.GlobalSettings)
local fxmod = require(modules.FXModule)
local notifMod = require(replicatedStorage.INTERACT_Assets.Modules.NotifModule) --Interact system shared module

local dmgMessages =	{"Damaged!", "Hit!", "Penetrated!"}
local critMessages = {"Critical Hit!", "Critically Damaged!"}
local deadMessages = {"Destroyed!", "Neutralized!", "Eliminated!"}
local bounceMessages = {"Bounced!", "Scraped!", "Not damaged!"}
local notifMessages =
	{
		TeamKill = --Prefix, player name, suffix
		{
			[[<font color="#00aaff">]].."[Teammate ", --Player name
			"]"..[[</font>]].." Killed!"
		},
		Kill =
		{
			[[<font color="#d39650">]].."[", --Player name
			"]"..[[</font>]].." Killed!"
		},
		TeamDeath =
		{
			[[<font color="#d30000">]].."Killed by "..[[</font>]]..[[<font color="#00aaff"> ]].."[", --Player name
			"]"..[[</font>]]
		},
		Death = 
		{
			[[<font color="#d30000">]].."Killed by ".."[", --Player name
			"]"..[[</font>]]
		},
		NonPlayer = "Environment" --what name should appear if a player is not killed by another player but by something else?
	}
local notifTags = --Notifications with matching tags will stack
	{
		TeamKill = "DTS_TKill",
		TeamDeath = "DTS_TDeath",
		Kill = "DTS_Kill",
		Death = "DTS_Death",
		
		VicPen = "DTS_VicPen",
		VicBounce = "DTS_VicBounce",
		VicKill = "DTS_VicKill",
		VicCrit = "DTS_VicCrit"
	}

--// Functions
local function ParentCheck(Part:BasePart, ParentName:string, Times:number)
	local tries = 0
	Times = Times or 6
	local currentPart = Part
	while currentPart and tries < Times do
		if currentPart.Name == ParentName then return currentPart end
		currentPart = currentPart.Parent
		tries += 1
	end
	return nil
end

local function ParentCheckII(Part:BasePart, TargetName:string)
	local ancestor = Part.Parent
	while ancestor do
		local partB = ancestor:FindFirstChild(TargetName)
		if partB then return partB end
		ancestor = ancestor.Parent
	end
	return nil
end

local function DestructionSequence(Prop:Model, DSFolder:Configuration)
	local curHP = Prop:GetAttribute("Prop_HP")
	local maxHP = Prop:GetAttribute("Prop_MaxHP")
	local percent = curHP/maxHP*100

	for each, seqEvent in DSFolder:GetChildren() do
		if percent<=tonumber(seqEvent.Name) and seqEvent.Value then
			if seqEvent.Value:IsA("Model") or seqEvent.Value:IsA("BasePart") then
				seqEvent.Value:Destroy()
			elseif seqEvent.Value:IsA("Weld") and seqEvent.Value.Name=="WeakWeld" then
				local despawnTimer = seqEvent.Value:FindFirstChild("TimedDespawn")
				if despawnTimer then debris:AddItem(despawnTimer.Value, despawnTimer:GetAttribute("Time")) end

				local weakWeldSound = seqEvent.Value.Parent:FindFirstChild("WeakWeld_Sound")
				if weakWeldSound then weakWeldSound:Play() end
				seqEvent.Value:Destroy()
			end
			Prop:SetAttribute("Prop_MaxHP", tonumber(seqEvent.Name))
			seqEvent:Destroy()
		end
	end

	--Self destruction
	local deadHP = DSFolder:GetAttribute("SelfDestruct_Threshold") or 0
	local deadTimer = DSFolder:GetAttribute("SelfDestruct_Timer") or 0.1
	if percent <= deadHP then
		Prop:SetAttribute("Prop_HP", 0)
		Prop:AddTag("PropSystem_Destroyed")
		debris:AddItem(Prop, deadTimer)
	end
end

local function EnableLightII(lightPart, bool)
	for each, thing in pairs(lightPart:GetChildren()) do
		if thing:IsA("SurfaceLight") or thing:IsA("SpotLight") or thing:IsA("PointLight") then 
			thing.Enabled = bool 
			thing:Destroy()
		elseif thing:IsA("Attachment") then
			EnableLightII(thing, bool)
		end
	end
end

--// Core Functions
function atmod.ParentCheckIII(Part:BasePart, ParentTag:string, Times:number)
	local tries = 0
	Times = Times or 6
	local currentPart = Part
	while currentPart and tries < Times do
		if currentPart:HasTag(ParentTag) then return currentPart end
		currentPart = currentPart.Parent
		tries += 1
	end
	return nil
end

function atmod.GetOccupants(target)
	local occupants = {}
	for _, Seat in ipairs(target:GetDescendants()) do
		if Seat:IsA("Seat") or Seat:IsA("VehicleSeat") then
			if Seat.Occupant then table.insert(occupants, Seat.Occupant) end
		end
	end
end

function atmod.TeamKillCheck(player1:Player, player2:Player):boolean --true: Kill allowed, false: kill prohibited
	-- Teamkill stuff
	--if not config.FriendlyFire and not player1.Neutral and not player2.Neutral then
	--	if player1.Team == player2.Team then
	--		return false
	--	end
	--end
	--return true
	
	local playerTeam = (player1 and player1.Team)
	local victimTeam = (player2 and player2.Team)
	
	return config.FriendlyFire or player1.Team ~= player2.Team
end

function atmod.TeamKillCheck2(player:Player, vehicle:Model):boolean --true: Kill allowed, false: kill prohibited
	local playerTeam = (player and player.Team and player.Team.Name) or "Default"
	local vicTeam = (vehicle and vehicle:GetAttribute("Vehicle_Team") or vehicle:GetAttribute("Prop_Team")) or "Default"
	
	return config.FriendlyFire or playerTeam~=vicTeam
end

function atmod.TagCheck(part, excludeType)
	if excludeType=="Vehicles" then
		if not part:HasTag("Dragoon_Armor") then return end
		local check1 = atmod.ParentCheckIII(part, "Dragoon_Vehicle")
		local check2 = atmod.ParentCheckIII(part, "Okami_Chassis")
		local check3 = atmod.ParentCheckIII(part, "Dragoon_Compat")
		return (check1 or check2 or check3)
	elseif excludeType=="Props" then
		if not part:HasTag("PropSystem_Armor") then return end
		return atmod.ParentCheckIII(part, "PropSystem_Object")
	end
end

function atmod.RoadKill(funcPart:BasePart, hitPart:BasePart, killer:Player, targets:{}, damage:{})
	if not hitPart or not hitPart:IsA("BasePart") or not hitPart.Parent then return end

	local victim:Humanoid = config.RoadkillPlayers and hitPart.Parent:FindFirstChildWhichIsA("Humanoid")
	local vehicle:Model = config.RoadkillVehicles and hitPart:HasTag("Dragoon_Armor") and atmod.TagCheck(hitPart, "Vehicles")
	local prop:Model = config.RoadkillProps and hitPart:HasTag("PropSystem_Armor") and atmod.TagCheck(hitPart, "Props")

	if victim and not table.find(targets, victim) and not victim.Sit and not victim.Parent:FindFirstChildWhichIsA("ForceField") then
		atmod.DamagePlayer(killer, victim, damage[3], damage[4], true)
		return victim
	elseif vehicle and not table.find(targets, vehicle) and not vehicle:HasTag("Dragoon_NoRoadkill") and atmod.TeamKillCheck2(killer, vehicle) then
		atmod.DamageVehicle(killer, hitPart, damage[1], damage[2], damage[4], true)
		return vehicle
	elseif prop and not table.find(targets, prop) and not prop:HasTag("Dragoon_NoRoadkill") and atmod.TeamKillCheck2(killer, prop) then
		atmod.DamageProp(killer, hitPart, damage[1], damage[2], damage[4], true)
		return prop
	elseif vehicle then
		return
	end
	
	atmod.DamageMisc(killer, hitPart, hitPart.Position, funcPart.Position, damage[1], damage[2], damage[3], damage[4], true)
end

function atmod.DealDamage(originPos:Vector3, hitPart:BasePart, killer:Player, targets:{}, damage:{})
	if not hitPart or not hitPart:IsA("BasePart") or not hitPart.Parent then return end

	local victim:Humanoid = hitPart.Parent:FindFirstChildWhichIsA("Humanoid")
	local vehicle:Model = hitPart:HasTag("Dragoon_Armor") and atmod.TagCheck(hitPart, "Vehicles")
	local prop:Model = hitPart:HasTag("PropSystem_Armor") and atmod.TagCheck(hitPart, "Props")

	if victim and not table.find(targets, victim) and not victim.Sit and not victim.Parent:FindFirstChildWhichIsA("ForceField") then
		atmod.DamagePlayer(killer, victim, damage[3], damage[4], true)
		return victim
	elseif vehicle and not table.find(targets, vehicle) and not vehicle:HasTag("Dragoon_NoRoadkill") and atmod.TeamKillCheck2(killer, vehicle) then
		atmod.DamageVehicle(killer, hitPart, damage[1], damage[2], damage[4], true)
		return vehicle
	elseif prop and not table.find(targets, prop) and not prop:HasTag("Dragoon_NoRoadkill") and atmod.TeamKillCheck2(killer, prop) then
		atmod.DamageProp(killer, hitPart, damage[1], damage[2], damage[4], true)
		return prop
	elseif vehicle then
		return
	end

	atmod.DamageMisc(killer, hitPart, hitPart.Position, originPos, damage[1], damage[2], damage[3], damage[4], true)
end

function atmod.DamageMisc(player:Player, hitPart:BasePart, hitPos:Vector3, originPos:Vector3, pen:number, dmg:number, plrDmg:number, knockback:number, directHit:boolean)
	if not hitPart then return end
	local isVehicle = atmod.TagCheck(hitPart, "Vehicles")

	--Destroy lights
	if hitPart:HasTag("LightPart_Auto") or hitPart:HasTag("LightPart") then
		EnableLightII(hitPart, false)
		hitPart:RemoveTag("LightPart_Auto")
		hitPart:RemoveTag("LightPart") 
		if hitPart:GetAttribute("LBrick_ColorOff") and hitPart:GetAttribute("LBrick_ChangeMaterial") then
			hitPart.Material = Enum.Material.Glass
			hitPart.Color = hitPart:GetAttribute("LBrick_ColorOff")
		end
	end

	--Destroy weak welds
	local weakWeld = hitPart:FindFirstChild("WeakWeld")
	if weakWeld then
		local DIR_DMG = weakWeld:GetAttribute("Hit_Damage")
		local DIR_PEN = weakWeld:GetAttribute("Hit_Pen")
		local AOE_DMG = weakWeld:GetAttribute("AOE_Damage") or DIR_DMG
		local AOE_PEN = weakWeld:GetAttribute("AOE_Pen") or DIR_PEN

		if ((directHit and DIR_DMG and dmg>=DIR_DMG) or (not directHit and AOE_DMG and dmg>=AOE_DMG)) and ((directHit and DIR_PEN and pen>=DIR_PEN) or (not directHit and AOE_PEN and pen>=AOE_PEN)) then
			local despawnTimer = weakWeld:FindFirstChild("TimedDespawn")
			if despawnTimer then debris:AddItem(despawnTimer.Value, despawnTimer:GetAttribute("Time")) end

			local weakWeldSound = weakWeld.Parent:FindFirstChild("WeakWeld_Sound")
			if weakWeldSound then weakWeldSound:Play() end

			weakWeld:Destroy()
		end
	end

	--Apply a force to unanchored parts
	if not hitPart.Anchored and not isVehicle then 
		--Apply knockback
		if knockback then
			local tempAtt = Instance.new("Attachment")
			tempAtt.Parent = hitPart
			tempAtt.Name = "ExplosionForce"
			local force = Instance.new("VectorForce",tempAtt)
			force.Attachment0 = tempAtt
			force.Force = knockback
			debris:AddItem(tempAtt,0.1)	
		end
	end
end

function atmod.DamagePlayer(player:Player, victim:Humanoid, plrDmg:number, knockback:number, directHit:boolean)
	--print("Player direct hit:", directHit)
	local victimPlayer:Player? = victim and players:GetPlayerFromCharacter(victim.Parent)
	local victimName:string = (config.leaderboardDisplayNames and victimPlayer and victimPlayer.DisplayName) or (victimPlayer and victimPlayer.Name) or (victim.DisplayName~="" and victim.DisplayName) or victim.Name
	local killerHuman:Humanoid = player and player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
	local killerName:string = (config.leaderboardDisplayNames and player and player.DisplayName) or (player and player.Name) or (killerHuman and killerHuman.DisplayName~=nil and killerHuman.DisplayName) or (killerHuman and killerHuman.Name) or notifMessages.NonPlayer

	if player and victimPlayer and not atmod.TeamKillCheck(player, victimPlayer) then return end

	--Apply knockback
	local humanRoot = victim.Parent:FindFirstChild("HumanoidRootPart")
	if knockback and humanRoot then
		local tempAtt = Instance.new("Attachment")
		tempAtt.Parent = humanRoot
		tempAtt.Name = "ExplosionForce"
		local force = Instance.new("VectorForce",tempAtt)
		force.Attachment0 = tempAtt
		force.Force = knockback
		debris:AddItem(tempAtt,0.1)	
	end

	if victim.Health > 0 and victim.Health-plrDmg <= 0 then
		--Leaderboard and kill counts
		if player then
			local leaderstats = player:FindFirstChild("leaderstats")
			if config.leaderboard and leaderstats then 
				if victimPlayer and player.Team==victimPlayer.Team then --Team kill!!
					local playerStat = leaderstats:FindFirstChild(config.leaderboardTKStat or "TK")
					local playerStat2 = leaderstats:FindFirstChild(config.leaderboardKillStat or "K" or "KO")
					if playerStat then
						playerStat.Value += 1
					elseif playerStat2 then
						playerStat2.Value += 1
					end
				else --Player kills
					local playerStat = leaderstats:FindFirstChild(config.leaderboardKillStat or "K" or "KO")
					if playerStat then
						playerStat.Value += 1
					end
				end
			end

			--This should work with most roblox leaderboards
			local killer = Instance.new("ObjectValue")
			killer.Name = "Killer"
			killer.Value = player
			killer.Parent = victim.Parent

			local creator = Instance.new("ObjectValue")
			creator.Name = "creator"
			creator.Value = player
			creator.Parent = victim
		end

		--Notifications
		if player and victimPlayer and player.Team==victimPlayer.Team then
			notifMod.Notificate(player, false, "LowerMid", 6, notifMessages.TeamKill[1]..victimName..notifMessages.TeamKill[2], notifTags.TeamKill)
			notifMod.Notificate(victimPlayer, false, "LowerMid", 6, notifMessages.TeamDeath[1]..killerName..notifMessages.TeamDeath[2], notifTags.TeamDeath)
		elseif player and victimPlayer then
			notifMod.Notificate(player, false, "LowerMid", 6, notifMessages.Kill[1]..victimName..notifMessages.Kill[2], notifTags.Kill)
			notifMod.Notificate(victimPlayer, false, "LowerMid", 6, notifMessages.Death[1]..killerName..notifMessages.Death[2], notifTags.Death)
		elseif player then
			notifMod.Notificate(player, false, "LowerMid", 6, notifMessages.Kill[1]..victimName..notifMessages.Kill[2], notifTags.Kill)
		elseif victimPlayer then
			notifMod.Notificate(victimPlayer, false, "LowerMid", 6, notifMessages.Death[1]..killerName..notifMessages.Death[2], notifTags.Death)
		end

	end
	victim:TakeDamage(plrDmg) --Deal damage based on range, kill if too close
end

function atmod.DamageProp(player:Player, hitPart:BasePart, pen:number, dmg:number, knockback:number, directHit:boolean)
	--print("Prop direct hit:", directHit)
	if not hitPart:HasTag("PropSystem_Armor") then return end

	local targetProp:Model = atmod.TagCheck(hitPart, "Props")
	if not targetProp then return end

	if targetProp:HasTag("PropSystem_Destroyed") or not atmod.TeamKillCheck2(player, targetProp) then return end

	local partMM = hitPart:GetAttribute("Armor_Thickness")
	local partDM = hitPart:GetAttribute("Armor_DmgMult")

	if pen >= partMM then --Successful pen!
		local propHP = targetProp:GetAttribute("Prop_HP")
		local propName = targetProp:GetAttribute("Prop_Name") or targetProp.Name
		local dmgReceived = dmg*partDM

		local notifMessage
		local notifTag
		local notifSound
		if dmgReceived>=propHP then
			notifMessage = [[<font color="#d39650"> ]].."["..propName.."] "..[[</font>]]..deadMessages[math.random(1, #deadMessages)]
			notifTag = notifTags.VicKill
		elseif partDM>1.25 then  --31b1b
			notifMessage = [[<font color="#d39650"> ]].."["..propName.."] "..[[</font>]]..critMessages[math.random(1, #critMessages)]..[[<font color="#e31b1b"> ]].." ["..math.floor(dmgReceived).."] "..[[</font>]]
			notifTag = notifTags.VicCrit
			notifSound = "DTS_Critical"
		else
			notifMessage = [[<font color="#d39650"> ]].."["..propName.."] "..[[</font>]]..dmgMessages[math.random(1, #dmgMessages)]..[[<font color="#ee4545"> ]].." ["..math.floor(dmgReceived).."] "..[[</font>]]
			notifTag = notifTags.VicPen
		end
		
		targetProp:SetAttribute("Prop_HP", math.max(propHP-dmgReceived, 0))
		fxmod.PlayFX(player, hitPart, "Armor_Pen")
		if player then notifMod.Notificate(player, false, "LowerMid", 3, notifMessage, notifTag, notifSound) end
	elseif pen < partMM then --Bounce, no damage!
		local propName = targetProp:GetAttribute("Prop_Name") or targetProp.Name
		local notifMessage = [[<font color="#d39650"> ]].."["..propName.."] "..[[</font>]]..bounceMessages[math.random(1, #bounceMessages)]
		if player then 	notifMod.Notificate(player, false, "LowerMid", 3, notifMessage, notifTags.VicBounce) end
	end

	--Destruction sequence
	local DestSeq = targetProp:FindFirstChild("DestructionSequence")
	if DestSeq then
		DestructionSequence(targetProp, DestSeq)
	end

	--Sounds
	local Mass = targetProp:FindFirstChild("Mass")
	local Hit = Mass and Mass:FindFirstChild("Hit")
	if Mass and Hit then
		Hit:Play()
	end

	--Apply knockback
	if knockback then
		local tempAtt = Instance.new("Attachment")
		tempAtt.Parent = hitPart
		tempAtt.Name = "ExplosionForce"
		local force = Instance.new("VectorForce",tempAtt)
		force.Attachment0 = tempAtt
		force.Force = knockback
		debris:AddItem(tempAtt,0.1)	
	end
end

function atmod.DamageVehicle(player:Player, hitPart:BasePart, pen:number, dmg:number, knockback:number, directHit:boolean)
	--print("Vehicle direct hit:", directHit)
	if not hitPart:HasTag("Dragoon_Armor") then return end

	local targetVic:Model = atmod.TagCheck(hitPart, "Vehicles")
	if not targetVic then return end
	if targetVic:HasTag("Dragoon_Destroyed") or not atmod.TeamKillCheck2(player, targetVic) then return end

	local partMM = hitPart:GetAttribute("Armor_Thickness")
	local partDM = hitPart:GetAttribute("Armor_DmgMult")

	if pen >= partMM then --Successful pen!
		local vehicleHP = targetVic:GetAttribute("Vehicle_HP")
		local vehicleName = targetVic:GetAttribute("Vehicle_Name")
		local dmgReceived = dmg*partDM

		local notifMessage
		local notifTag
		local notifSound
		if dmgReceived>=vehicleHP then
			notifMessage = [[<font color="#d39650"> ]].."["..vehicleName.."] "..[[</font>]]..deadMessages[math.random(1, #deadMessages)]

			if player then 
				local killerTag = Instance.new("ObjectValue")
				killerTag.Name = "Killer"
				killerTag.Value = player
				killerTag.Parent = targetVic
			end
			notifTag = notifTags.VicKill
		elseif partDM>1.25 then  --31b1b
			notifMessage = [[<font color="#d39650"> ]].."["..vehicleName.."] "..[[</font>]]..critMessages[math.random(1, #critMessages)]..[[<font color="#e31b1b"> ]].." ["..math.floor(dmgReceived).."] "..[[</font>]]
			notifTag = notifTags.VicCrit
			notifSound = "DTS_Critical"
		else
			notifMessage = [[<font color="#d39650"> ]].."["..vehicleName.."] "..[[</font>]]..dmgMessages[math.random(1, #dmgMessages)]..[[<font color="#ee4545"> ]].." ["..math.floor(dmgReceived).."] "..[[</font>]]
			notifTag = notifTags.VicPen
		end

		fxmod.PlayFX(player, hitPart, "Armor_Pen")
		if player then notifMod.Notificate(player, false, "LowerMid", 3, notifMessage, notifTag, notifSound) end
		targetVic:SetAttribute("Vehicle_HP", math.max(vehicleHP-dmgReceived, 0))
	elseif pen < partMM then --Bounce, no damage!
		local vehicleName = targetVic:GetAttribute("Vehicle_Name")
		local notifMessage = [[<font color="#d39650"> ]].."["..vehicleName.."] "..[[</font>]]..bounceMessages[math.random(1, #bounceMessages)]

		--fxmod.PlayFX(player, hitPart, "Armor_Bounce")
		if player then notifMod.Notificate(player, false, "LowerMid", 3, notifMessage, notifTags.VicBounce) end
	end

	--Apply knockback
	knockback = false --vehicle knockback DISABLED
	if knockback then
		local tempAtt = Instance.new("Attachment")
		tempAtt.Parent = hitPart
		tempAtt.Name = "ExplosionForce"
		local force = Instance.new("VectorForce",tempAtt)
		force.Attachment0 = tempAtt
		force.Force = knockback
		game.Debris:AddItem(tempAtt,0.1)	
	end
end

return atmod