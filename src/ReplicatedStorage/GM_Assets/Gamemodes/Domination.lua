-- system variables
local Assets = game.ReplicatedStorage.GM_Assets
local Vars = Assets.Vars
local Timer = Vars.Timer
local Config = require(Assets.GameSettings)
local Teams = game.Teams

local notifMod = require(game.ReplicatedStorage.INTERACT_Assets.Modules.NotifModule) --Interact system shared module

-- domination variables
local Domination_Workspace = game.Workspace.GM_Domination

local mode = {}
-- change these
mode.modeDefaultSettings = { -- each setting in this table can be read by the Admin Panel.
	["roundLength"] = 180, -- the length, in seconds, of a round in this mode
	["pointsToWin"] = 1000, -- points needed for a team to win
}

mode.Icon = 18349302002

-- utility
mode.isActive = false
mode.timeLeft = 0
mode.pointsToWin = 0 -- change pointsToWin in ^ modeDefaultSettings ^ if you want to change the default, this is overwritten when the game starts

-- points
mode.resetPoints = true -- reset players' scores and kill counts at the start of each match?
mode.pointsPerKill = 0 -- how many points do you get for killing someone?
mode.pointsPerCapture = 5 -- how many points does a player get for capturing a point?
mode.pointsPerSecond = 1 -- how many points does the team get for holding a point for one second?
mode.timeToCapture = 15 -- how long does it take to capture a point?

-- points
mode.capturePoints = {}

function ResetCapturePoints()
	mode.capturePoints = {}
	for _, point in Domination_Workspace.Points:GetChildren() do
		table.insert(mode.capturePoints, point)
		point:SetAttribute("lastPointGiven", 0)
		point:SetAttribute("pointTakenBy",nil)
		point:SetAttribute("pointContestedBy", nil)
		point:SetAttribute("pointContestedFor", 0)
		point.PointLabel.NameLabel.Text = point.Name
		point.PointLabel.Enabled = mode.isActive
		UpdatePoint(point, Config.neutralColor)
	end
end

function AwardPointCapture(point, player)
	local notifMessage = [[<font color="#d30000"> ]].."["..point.Name.."]"..[[</font>]].." Captured!".." +"..mode.pointsPerCapture
	notifMod.Notificate(player, false, "LowerMid", 6, notifMessage)
	-- award points to player
	local stats = player:findFirstChild("leaderstats")
	if stats ~= nil then
		local points = stats:findFirstChild("Points")
		points.Value = points.Value +mode.pointsPerCapture
	end

	if player.Team.Name ~= Config.lobbyTeam then
		-- add points to team
		player.Team:SetAttribute("Points", player.Team:GetAttribute("Points") +mode.pointsPerCapture)

		-- add points to faction
		if Config.Teams[player.Team.Name] then
			if Config.Teams[player.Team.Name]["Faction"] == "A" then
				Vars.factionAScore.Value += mode.pointsPerCapture
			elseif Config.Teams[player.Team.Name]["Faction"] == "B" then
				Vars.factionBScore.Value += mode.pointsPerCapture
			end
		else
			warn("Player's team is not in GameSettings!")
		end
	end
end

function UpdatePoint(point, color)
	point.CaptureCircle.Color = color
	point.CapturePart.Color = color
	point.CapturePart.CaptureLight.Color = color
	point.PointLabel.NameLabel.TextColor3 = color
end



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
	ResetCapturePoints()
	notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, "Game Begins!")
end

function mode.onRoundEnd()
	mode.isActive = false
	task.wait(5)
	Vars.roundActive.Value = false
	Vars.roundType.Value = ""
	Timer.Value = 0
	ResetScore()
	ResetCapturePoints()
	notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, "Game Ends.")
end

function mode.OnKill(player, killer)
	-- award points to player
	local stats = killer:findFirstChild("leaderstats")
	local points = stats:findFirstChild("Points")
	if stats ~= nil then
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

	for _, point in mode.capturePoints do
		local charactersOnPoint = {}
		local numFaction1 = 0
		local numFaction2 = 0
		local pointTakenBy = point:GetAttribute("pointTakenBy") -- who owns this point at present?
		local lastPointGiven = point:GetAttribute("lastPointGiven") -- how long has it been since this capture point awarded points for being held?
		local pointContestedBy = point:GetAttribute("pointContestedBy") -- who is contesting this point?
		local pointContestedFor = point:GetAttribute("pointContestedFor") -- how long have they been contesting it?

		for i, plr in pairs(game.Players:GetChildren()) do
			local char = plr.Character
			if char and char:FindFirstChild("Humanoid") then
				if char.Humanoid.Health > 0 and char:FindFirstChild("HumanoidRootPart") and (char.HumanoidRootPart.Position * Vector3.new(1, 0, 1) - point.PrimaryPart.Position * Vector3.new(1, 0, 1)).Magnitude <= point.PrimaryPart.Size.Z/2 then
					if not table.find(charactersOnPoint, char) then
						table.insert(charactersOnPoint, char)
					end
				elseif table.find(charactersOnPoint, char) then
					table.remove(charactersOnPoint, table.find(charactersOnPoint, char))
				end
			end
		end

		for i, charOnPoint in pairs(charactersOnPoint) do
			local plr = game.Players:GetPlayerFromCharacter(charOnPoint)
			if plr then
				if Config.Teams[plr.Team.Name] then
					if Config.Teams[plr.Team.Name]["Faction"] == "A" then
						numFaction1 += 1
					elseif Config.Teams[plr.Team.Name]["Faction"] == "B" then
						numFaction2 += 1
					end
				else
					if plr.Team.Name ~= Config.lobbyTeam then
						warn("Player's team is not in GameSettings!")
					end
				end
			end
		end

		if numFaction1 > 0 and numFaction2 == 0 then
			if not pointContestedBy or pointContestedBy ~= "A" then
				point:SetAttribute("pointContestedBy", "A")
				point:SetAttribute("pointContestedFor", 0)
			elseif pointContestedBy == "A" then
				if pointContestedFor >= (mode.timeToCapture * 120) then
					if pointContestedBy ~= point:GetAttribute("pointTakenBy") then
						for i, charOnPoint in pairs(charactersOnPoint) do
							local plr = game.Players:GetPlayerFromCharacter(charOnPoint)
							if plr then
								if Config.Teams[plr.Team.Name]["Faction"] == "A" then
									AwardPointCapture(point, plr)
								end
							end
						end
					end
					point:SetAttribute("pointTakenBy","A")
				end
			end

		elseif numFaction2 > 0 and numFaction1 == 0 then
			if not pointContestedBy or pointContestedBy ~= "B" then
				point:SetAttribute("pointContestedBy", "B")
				point:SetAttribute("pointContestedFor", 0)
			elseif pointContestedBy == "B" then
				if pointContestedFor >= (mode.timeToCapture * 120) then
					if pointContestedBy ~= point:GetAttribute("pointTakenBy") then
						for i, charOnPoint in pairs(charactersOnPoint) do
							local plr = game.Players:GetPlayerFromCharacter(charOnPoint)
							if plr then
								if Config.Teams[plr.Team.Name]["Faction"] == "B" then
									AwardPointCapture(point, plr)
								end
							end
						end
					end
					point:SetAttribute("pointTakenBy","B")
				end
			end

		elseif (numFaction1 ~= 0 and numFaction2 ~= 0) or (numFaction1 == 0 and numFaction2 == 0) then
			point:SetAttribute("pointContestedBy",nil)
			if pointContestedFor > 0 then
				point:SetAttribute("pointContestedFor", pointContestedFor - 1)
			else
				point:SetAttribute("pointContestedFor", 0)
			end
		end

		if pointContestedBy then
			point:SetAttribute("pointContestedFor", (point:GetAttribute("pointContestedFor") + 1))
			if pointTakenBy then
				if pointContestedBy ~= pointTakenBy then
					local pointColor = Config.Factions[pointTakenBy]["Color"]
					local contestingColor = Config.Factions[pointContestedBy]["Color"]
					local colorToPaint = pointColor:Lerp(contestingColor, 0.5)
					UpdatePoint(point, colorToPaint)
				else
					point:SetAttribute("pointContestedFor", 0)
				end
			else
				local pointColor = Config.neutralColor
				local contestingColor = Config.Factions[pointContestedBy]["Color"]
				local colorToPaint = pointColor:Lerp(contestingColor, 0.5)
				UpdatePoint(point, colorToPaint)
			end
		else
			if pointContestedFor > 0 then
				point:SetAttribute("pointContestedFor", pointContestedFor - 1)
			end
			UpdatePoint(point, Config.neutralColor)
		end


		if pointTakenBy then
			UpdatePoint(point, Config.Factions[pointTakenBy]["Color"])
			if lastPointGiven >= 120 then
				if pointTakenBy == "A" then
					Vars.factionAScore.Value += mode.pointsPerSecond
					point:SetAttribute("lastPointGiven", 0)
				elseif pointTakenBy == "B" then
					Vars.factionBScore.Value += mode.pointsPerSecond
					point:SetAttribute("lastPointGiven", 0)
				end
			end
			point:SetAttribute("lastPointGiven", (point:GetAttribute("lastPointGiven") + 1))
		else
			if not pointContestedBy then
				UpdatePoint(point, Config.neutralColor)
			end
		end
	end

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
		if Vars.factionAScore.Value > Vars.factionBScore.Value then -- faction A has more points
			notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, [[<font color="#00aaff">]]..Config.Factions["A"]["Name"]..[[</font>]].." Wins!")
		elseif Vars.factionAScore.Value < Vars.factionBScore.Value then -- faction B has more points
			notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, [[<font color="#d30000">]]..Config.Factions["B"]["Name"]..[[</font>]].." Wins!")
		else -- both factions have the same amount of points
			notifMod.Notificate(game.Players:FindFirstChildWhichIsA("Player"), true, "LowerMid", 6, "Stalemate")
		end
		mode.onRoundEnd()
	end
end


return mode