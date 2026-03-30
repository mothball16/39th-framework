-- system variables
local Assets = game.ReplicatedStorage.GM_Assets
local Vars = Assets.Vars
local Timer = Vars.Timer
local Config = require(Assets.GameSettings)
local Teams = game.Teams

local notifMod = require(game.ReplicatedStorage.INTERACT_Assets.Modules.NotifModule) --Interact system shared module

local mode = {}
-- change these
mode.modeDefaultSettings = { -- each setting in this table can be read by the Admin Panel.
	["roundLength"] = 180, -- the length, in seconds, of a round in this mode
	["pointsToWin"] = 10, -- points needed for a team to win
}

mode.Icon = 18336823929

-- utility
mode.isActive = false
mode.timeLeft = 0
mode.pointsToWin = 0 -- change pointsToWin in ^ modeDefaultSettings ^ if you want to change the default, this is overwritten when the game starts

-- points
mode.resetPoints = true -- reset players' scores and kill counts at the start of each match?
mode.pointsPerKill = 1

function ResetScore()
	Vars.factionAScore.Value = 0
	Vars.factionBScore.Value = 0	
	for _, teem in game.Teams:GetChildren() do -- go through all the teams in the game
		teem:SetAttribute("Points", 0)
	end
	if mode.resetPoints then
		for _, plr in game.Players:GetChildren() do
			local stats = plr:FindFirstChild("leaderstats")
			if stats ~= nil then
				local KOs = stats.KOs
				local WOs = stats.Wipeouts
				local Pts = stats.Points
				KOs.Value = 0
				WOs.Value = 0
				Pts.Value = 0
			end
		end
	end
end

function mode.onRoundStart(roundSettings)
	mode.isActive = true
	mode.timeLeft = roundSettings["roundLength"] or mode.modeDefaultSettings["roundLength"]
	mode.pointsToWin = roundSettings["pointsToWin"] or mode.modeDefaultSettings["pointsToWin"]
	ResetScore()
	notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, "Game Begins!")
end

function mode.onRoundEnd()
	mode.isActive = false
	task.wait(5)
	Vars.roundActive.Value = false
	Vars.roundType.Value = ""
	Timer.Value = 0
	ResetScore()
	notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, "Game Ends.")
end

function mode.OnKill(player, killer)
	-- award points to player
	local stats = killer:findFirstChild("leaderstats")
	if stats ~= nil then
		local points = stats:findFirstChild("Points")
		points.Value = points.Value +mode.pointsPerKill
	end

	if killer.Team.Name ~= Config.lobbyTeam then
		-- add points to team
		killer.Team:SetAttribute("Points", killer.Team:GetAttribute("Points") +mode.pointsPerKill)

		-- add points to faction
		if Config.Teams[killer.Team.Name] then
			if Config.Teams[killer.Team.Name]["Faction"] == "A" then
				Vars.factionAScore.Value += mode.pointsPerKill
			elseif Config.Teams[killer.Team.Name]["Faction"] == "B" then
				Vars.factionBScore.Value += mode.pointsPerKill
			end
		else
			warn("Player's team is not in GameSettings!")
		end
	end
end

function mode.runLoop(deltaTime)
	if not mode.isActive then return end
	mode.timeLeft -= deltaTime
	Timer.Value = math.round(mode.timeLeft,1)

	if (Vars.factionAScore.Value >= mode.pointsToWin) or (Vars.factionBScore.Value >= mode.pointsToWin) then -- Someone got over the threshold
		mode.isActive = false
		if Vars.factionAScore.Value > Vars.factionBScore.Value then -- faction A has more points
			notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, [[<font color="#00aaff">]]..Config.Factions["A"]["Name"]..[[</font>]].." Wins!")
		elseif Vars.factionAScore.Value < Vars.factionBScore.Value then -- faction B has more points
			notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, [[<font color="#d30000">]]..Config.Factions["B"]["Name"]..[[</font>]].." Wins!")
		else -- both factions have the same amount of points
			notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, "Stalemate")
		end
		mode.onRoundEnd()
	end

	if mode.timeLeft <= 0 then -- time ran out
		mode.isActive = false
		mode.timeLeft = 0
		if Vars.factionAScore.Value > Vars.factionBScore.Value then
			notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, [[<font color="#00aaff"> ]]..Config.Factions["A"]["Name"]..[[</font>]].." Wins!")
		elseif Vars.factionAScore.Value < Vars.factionBScore.Value then
			notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, [[<font color="#d30000"> ]]..Config.Factions["B"]["Name"]..[[</font>]].." Wins!")
		else
			notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, "Stalemate")
		end
		mode.onRoundEnd()
	end
end


return mode
