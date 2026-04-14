-- Game Master
-- by VanguardCobalt
-- v1.0
-- 12/27/2024

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local debris = game:GetService("Debris")

local Assets = game.ReplicatedStorage:WaitForChild("GM_Assets")
local Config = require(Assets.GameSettings)
local modules = Assets.Modules
local Vars = Assets.Vars

local bridgeNet = nil
if 	  Config.useSpearhead then bridgeNet = require(replicatedStorage.SPH_Assets.Modules.Network.BridgeNet)
else
	bridgeNet = require(modules.BridgeNet) end

local repStats = bridgeNet.CreateBridge("updateStats") -- update stats
local repStartRound = bridgeNet.CreateBridge("repStartRound") -- startRound
local repStopRound = bridgeNet.CreateBridge("repStopRound") -- stopRound

local notifMod = require(game.ReplicatedStorage.INTERACT_Assets.Modules.NotifModule) --Interact system shared module

-- user interface
local GUI = Assets.GUI
local AdminPanel = GUI.GM_MasterPanel

-- gamemode info
local g_modes = Assets.Gamemodes

-- round information
local inRound = Vars.roundActive
local roundType = Vars.roundType
local roundTypeModule
local Timer = Vars.Timer
local in_intermission = false

-- round functions

Vars.roundActive.Changed:Connect(function() -- listens for manual changes to roundActive (endless mode, admin use)
	if Vars.roundActive.Value == true then
		-- do nothing
	else
		if Config.Endless then
			intermission()
		end
	end
end)

function beginRound(mode, modeSettings)
	if not (inRound.Value == true) and roundType.Value == "" then -- ensure no round is currently running
		roundTypeModule = require(mode)
		notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, "Starting round type: "..mode.Name)
		roundTypeModule.onRoundStart(modeSettings)
		inRound.Value = true
		roundType.Value = mode.Name
		for i, player in pairs (game.Players:GetChildren()) do
			giveRoundUI(player)	
		end
		if Config.resetOnStart then -- reset all players on game start and end?
			for _, plr in game.Players:GetChildren() do
				if plr.Team.Name ~= Config.lobbyTeam then
					plr:LoadCharacter()
				end
			end
		end
	end
end

function endRound()
	-- stop the currently running round
	if inRound.Value == true and roundTypeModule then
		local roundToEnd = roundType.Value
		notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, "Stopping round type: "..roundToEnd)
		roundTypeModule.onRoundEnd()
		for i, player in pairs (game.Players:GetChildren()) do
			if player.PlayerGui:FindFirstChild("GUI_"..roundToEnd) then
				if roundToEnd ~= roundType.Value then
					player.PlayerGui["GUI_"..roundToEnd]:Destroy()
				end
			end
			if Config.resetOnStart then -- reset all players on game start and end?
				for _, plr in game.Players:GetChildren() do
					if plr.Team.Name ~= Config.lobbyTeam then
						plr:LoadCharacter()
					end
				end
			end
		end
	end
end

function intermission()
	if not in_intermission then
		print("Intermission_Success")
		in_intermission = true
		notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, "Entering intermission.")
		for i = Config.intermissionLength, 0, -1 do
			Timer.Value = i
			task.wait(1)
		end
		local EndlessModeModule = require(g_modes[Config.EndlessGameMode])
		local EndlessModeSettings = EndlessModeModule.modeDefaultSettings
		beginRound(Assets.Gamemodes[Config.EndlessGameMode], EndlessModeSettings)
		in_intermission = false
	end
end

repStartRound:Connect(function(player, selectedMode, selectedSettings) -- receive transmitted information
	local isAdmin = adminCheck(player) -- verify this player is permitted to stop rounds
	if isAdmin then
		beginRound(selectedMode, selectedSettings) -- start the round
	end
end)

repStopRound:Connect(function(player)
	local isAdmin = adminCheck(player) -- verify this player is permitted to stop rounds
	if isAdmin then
		endRound()
	end
end)

-- Round UI
function giveRoundUI(player)
	if roundType.Value ~= "" then
		if not player.PlayerGui:FindFirstChild("GUI_"..roundType.Value) then
			local newGui = GUI["GUI_"..roundType.Value]:Clone()
			newGui.Parent = player.PlayerGui
		end
	end
end


-- GM Admin Check
function giveAdmin(player)
	task.wait()
	if not player.PlayerGui:FindFirstChild("GM_MasterPanel") then
		local newGui = AdminPanel:Clone()
		newGui.Parent = player.PlayerGui
	end
end

function adminCheck(player)
	if(table.find(Config.userAdminList, player.Name)) then -- user whitelist check
		return true
	elseif Config.GroupAdminList then -- group whitelist check
		for group, i in Config.Groups do
			local gr_ranks = Config.Groups[group]["ranks"]
			if(table.find(gr_ranks, player:GetRankInGroup(Config.Groups[group]["id"]))) ~= nil then
				return true
			end
		end
	else
		return false
	end
end

-- leaderboard functions --

function onPlayerEntered(newPlayer)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = "KOs"
	kills.Value = 0
	local TeamKills = Instance.new("IntValue")
	TeamKills.Name = "TKs"
	TeamKills.Value = 0
	local deaths = Instance.new("IntValue")
	deaths.Name = "Wipeouts"
	deaths.Value = 0
	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Value = 0
	points.Parent = stats
	kills.Parent = stats
	deaths.Parent = stats
	TeamKills.Parent = stats
	
	local isAdmin = adminCheck(newPlayer) -- check if player is an admin
	if isAdmin then
		giveAdmin(newPlayer)
	end
	if roundType.Value ~= "" and inRound.Value == true then
		giveRoundUI(newPlayer)
	end
	
	while true do
		if newPlayer.Character ~= nil then break end
		task.wait(5)
	end
	local humanoid = newPlayer.Character.Humanoid
	humanoid.Died:connect(function() onHumanoidDied(humanoid, newPlayer) end )
	newPlayer.Changed:connect(function(property) onPlayerRespawn(property, newPlayer) end )
	stats.Parent = newPlayer
	
	newPlayer:GetAttributeChangedSignal("selectedSquad"):Connect(function() -- player changed squad
		repStats:FireAll()
	end)
	
	newPlayer:GetPropertyChangedSignal("Team"):Connect(function() -- player changed team
		repStats:FireAll()
	end)
	
	points.Changed:Connect(function() -- player gained or lost points
		repStats:FireAll()
	end)
	
	repStats:FireAll() -- update leaderboard now that new player is here
end

-- Starts Endless mode on game launch
if Config.Endless then
	local EndlessModeModule = require(g_modes[Config.EndlessGameMode])
	local EndlessModeSettings = EndlessModeModule.modeDefaultSettings
	beginRound(Assets.Gamemodes[Config.EndlessGameMode], EndlessModeSettings)
end

function Send_DB_Event_Died(victim, killer)
	local killername = "no one"
	if killer ~= nil then killername = killer.Name end
	if shared["deaths"] ~= nil then 
		shared["deaths"](victim, killer)
	end
end

function Send_DB_Event_Kill(killer, victim)
	if shared["kills"] ~= nil then 
		shared["kills"](killer, victim)
	end
end

function onHumanoidDied(humanoid, player)
	local stats = player:findFirstChild("leaderstats")
	if stats ~= nil then
		local deaths = stats:findFirstChild("Wipeouts")
		deaths.Value = deaths.Value + 1
		local killer = getKillerOfHumanoidIfStillInGame(humanoid)
		Send_DB_Event_Died(player, killer)
		handleKillCount(humanoid, player)
	end
	repStats:FireAll()
end

function onPlayerRespawn(property, player)
	if property == "Character" and player.Character ~= nil then
		local humanoid = player.Character.Humanoid
		local p = player
		local h = humanoid
		humanoid.Died:connect(function() onHumanoidDied(h, p) end )
		local isAdmin = adminCheck(player) -- check if player is an admin
		if isAdmin then
			giveAdmin(player)
		end
		if roundType.Value ~= "" and inRound.Value == true then -- give the player the round's GUI if none is there already
			giveRoundUI(player)
		end
	end
end

function getKillerOfHumanoidIfStillInGame(humanoid)
	local tag = humanoid:findFirstChild("creator")
	if tag ~= nil then
		local killer = tag.Value
		if killer.Parent ~= nil then
			return killer
		end
	end
	return nil
end

function processTeamKill(plr, tklr) -- what happens if theres a teamkill
	if Config.teamKillKick then
		local stats = tklr:findFirstChild("leaderstats")
		local tks = stats:findFirstChild("TKs")
		if stats ~= nil then
			if tks.Value >= Config.teamKillTotalThreshold then -- their total teamkill count exceeds the kick threshold
				tklr:Kick("Excessive teamkilling")
			end
			local streak = stats:findFirstChild("TK_Streak")
			if not streak then
				streak = Instance.new("IntValue", stats)
				streak.Name = "TK_Streak"
				streak.Value = 0
			end
			streak.Value += 1

			if streak.Value >= Config.teamKillStreakThreshold then -- their team killstreak exceeds the kick threshold
				tklr:Kick("Excessive teamkilling")
			end
		end
	end

	local notifMessage = [[<font color="#00aaff"> ]].."[Teammate "..plr.Name.."]"..[[</font>]].." Killed!"
	notifMod.Notificate(tklr, false, "LowerMid", 6, notifMessage)

	notifMessage = [[<font color="#d30000"> ]].."Killed by "..[[</font>]]..[[<font color="#00aaff"> ]].."["..tklr.Name.."]"..[[</font>]]
	notifMod.Notificate(plr, false, "LowerMid", 6, notifMessage)
end

function processKill(plr, klr) -- what happens if there's a kill
	if inRound and roundTypeModule then
		-- let the current gamemode know
		roundTypeModule.OnKill(plr, klr)
	end

	local notifMessage = [[<font color="#d30000"> ]].."["..plr.Name.."]"..[[</font>]].." Killed!"
	notifMod.Notificate(klr, false, "LowerMid", 6, notifMessage)

	notifMessage = [[<font color="#d30000"> ]].."Killed by ".."["..klr.Name.."]"..[[</font>]]
	notifMod.Notificate(plr, false, "LowerMid", 6, notifMessage)
end

function handleKillCount(humanoid, player)
	local killer = getKillerOfHumanoidIfStillInGame(humanoid)
	if killer ~= nil then
		local stats = killer:findFirstChild("leaderstats")
		if stats ~= nil then
			local kills = stats:findFirstChild("KOs")
			local tks = stats:findFirstChild("TKs")
			if killer ~= player then
				if killer.Team.Name == player.Team.Name then -- same team
					tks.Value = tks.Value +1
					processTeamKill(player, killer)
				else -- not the same team
					if Config.Teams[killer.Team.Name] and Config.Teams[player.Team.Name] then -- are the teams in the faction config?
						if Config.Teams[killer.Team.Name]["Faction"] == Config.Teams[player.Team.Name]["Faction"] then -- are they in the same faction?
							tks.Value = tks.Value +1
							processTeamKill(player, killer)
						else -- they aren't in the same faction
							kills.Value = kills.Value + 1
							processKill(player, killer)
						end
					else -- the teams are not in the faction config
						kills.Value = kills.Value + 1
						processKill(player,killer)
					end
				end
			end
		end
		Send_DB_Event_Kill(killer, player)
	end
end

-- heartbeat
game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
	if roundTypeModule and roundTypeModule.runLoop then
		roundTypeModule.runLoop(deltaTime)
	end
end)

game.Players.ChildAdded:connect(onPlayerEntered)
game.Players.ChildRemoved:Connect(function()
	task.wait(1)
	repStats:FireAll()
end)