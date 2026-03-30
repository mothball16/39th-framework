-- Services & Essentials
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local replicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local debris = game:GetService("Debris")
local teams = game:GetService("Teams")

-- DD Assets
local Assets = game.ReplicatedStorage:WaitForChild("GM_Assets")
local Config = require(Assets.GameSettings)
local modules = Assets.Modules
local Vars = Assets.Vars

-- Bridgenet
local bridgeNet = nil
if Config.useSpearhead then bridgeNet = require(replicatedStorage.SPH_Assets.Modules.BridgeNet)
else
	bridgeNet = require(modules.BridgeNet) end

local repStats = bridgeNet.CreateBridge("updateStats") -- update stats

-- UI Assets
local canvas = script.Parent.Canvas
local frame = canvas.TeamPlayerList
local sampleTeam = frame.SampleTeam
local samplePlayer = frame.SamplePlayer
local teamList = frame.TeamList

-- Disable default leaderboard
local StarterGUI = game:GetService("StarterGui")
StarterGUI:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

-- Function to toggle the visibility of the leaderboard
local function ToggleLeaderboardVisibility(ActionName, InputState, InputObject)
	if InputState ~= Enum.UserInputState.Begin then return end -- This will prevent the function from being called twice
	frame.Visible = not frame.Visible
end

-- Bind action to toggle the leaderboard visibility
local ContextActionService = game:GetService("ContextActionService")
ContextActionService:BindAction("RbxPlayerListToggle", ToggleLeaderboardVisibility, true, Enum.KeyCode.Tab)

-- Update the canvas size to reflect added or removed teams
local function UpdateCanvasSize(CanvasToUpdate, Constraint)
	CanvasToUpdate.CanvasSize = UDim2.new(0, Constraint.AbsoluteContentSize.X, 0, Constraint.AbsoluteContentSize.Y)
end

-- Cleanly calculate KDR
function getKDR(playerstats)
	local KD = 0
	if playerstats.KOs.Value ~= 0 and playerstats.Wipeouts.Value ~= 0 then
		KD = math.round((playerstats.KOs.Value / playerstats.Wipeouts.Value))
	end
	return KD
end

-- Add a new player into the leaderboard
function AddNewEntry(Player)
	if teamList[Player.Team.Name]:FindFirstChild(Player.Name) then return end

	local NewPlayerEntry = samplePlayer:Clone()
	local NewPlayerKOs = NewPlayerEntry.KOs
	local NewPlayerWOs = NewPlayerEntry.Deaths
	local NewPlayerPoints = NewPlayerEntry.Points
	local NewPlayerKDR = NewPlayerEntry.KDR

	NewPlayerEntry.Name = Player.Name
	if teamList[Player.Team.Name] then NewPlayerEntry.Parent = teamList[Player.Team.Name].PlayerList else
		AddNewTeam(Player.Team)
		task.wait(0.1)
		NewPlayerEntry.Parent = teamList[Player.Team.Name].PlayerList
	end
	NewPlayerEntry.Parent = teamList[Player.Team.Name].PlayerList
	NewPlayerEntry.Visible = true

	NewPlayerEntry.PlayerName.Text = Player.DisplayName	
	--if Player.GetAttribute("Class") ~= nil then NewPlayerEntry.PlayerClass.Image = "Cheeseburger" end
	if Config.groupRanks then 
		NewPlayerEntry.PlayerRank.Visible = true
		--NewPlayerEntry.PlayerRank.Image == i assume some sort of image
	else
		NewPlayerEntry.PlayerRank.Visible = false
	end

	-- update player stats
	local TgtStats = Player:WaitForChild("leaderstats")
	NewPlayerKOs.Text = TgtStats.KOs.Value
	NewPlayerWOs.Text = TgtStats.Wipeouts.Value
	NewPlayerPoints.Text = TgtStats.Points.Value
	NewPlayerKDR.Text = getKDR(TgtStats)

	-- is this player us?
	if Player == localPlayer then
		NewPlayerEntry.PlayerName.TextColor3 = Config.playerColor
	end

	-- rank this player by their points
	NewPlayerEntry.LayoutOrder = -TgtStats.Points.Value

	Player:GetPropertyChangedSignal("Team"):Connect(function() -- player changed team
		if teamList:FindFirstChild(Player.Team.Name) then
			NewPlayerEntry.Parent = teamList[Player.Team.Name].PlayerList
		end
	end)

	TgtStats.KOs.Changed:Connect(function(newval)
		NewPlayerKOs.Text = newval
		NewPlayerKDR.Text = getKDR(TgtStats)
	end)
	TgtStats.Wipeouts.Changed:Connect(function(newval)
		NewPlayerWOs.Text = newval
		NewPlayerKDR.Text = getKDR(TgtStats)
	end)
	TgtStats.Points.Changed:Connect(function(newval)
		NewPlayerPoints.Text = newval
		NewPlayerEntry.LayoutOrder = -TgtStats.Points.Value
	end)

	UpdateLeaderboard()
end

function AddNewTeam(Team) -- add a new team to the list
	if teamList:FindFirstChild(Team.Name) then return end

	local sTeam = sampleTeam:Clone()
	sTeam.Name = Team.Name
	sTeam.Parent = teamList
	sTeam.Visible = true

	task.wait()
	local tbar = sTeam.TeamTopbar
	tbar.TeamInfo.TeamName.Text = Team.Name

	if Config.Teams[Team.Name] then
		sTeam.TeamTopbar.TeamInfo.TeamLogo.Image = "rbxassetid://"..Config.Teams[Team.Name]["LogoID"]
	end

	if Config.groupRanks then 
		sTeam.TeamTopbar.TeamInfo.Rank.Visible = true
	else
		sTeam.TeamTopbar.TeamInfo.Rank.Visible = false
	end

	if Team:GetAttribute("Points") then
		tbar.TeamPoints.Text = Team:GetAttribute("Points")
	end

	Team:GetAttributeChangedSignal("Points"):Connect(function()
		tbar.TeamPoints.Text = Team:GetAttribute("Points")
	end)

	tbar.TeamInfo.TeamName.TextColor3 = Team.TeamColor.Color
	tbar.TeamInfo.TeamLogo.ImageColor3 = Team.TeamColor.Color
	tbar.TeamLine.BackgroundColor3 = Team.TeamColor.Color
	tbar.TeamPoints.TextColor3 = Team.TeamColor.Color

	UpdateCanvasSize(teamList, teamList.UIListLayout) -- update the size of the team list to reflect the new number of teams
	UpdateLeaderboard()
end

-- Update the values on the leaderboard
function UpdateLeaderboard()
	for _, teem in game.Teams:GetChildren() do -- go through all the teams in the game
		local listedTeam = teamList:FindFirstChild(teem.Name)
		if not listedTeam then
			if #teamList:GetChildren() > 0 then
				AddNewTeam(teem)
			else
				return
			end
		end
		if listedTeam then
			if teem == localPlayer.Team then listedTeam.LayoutOrder = -1 -- put the player's team up front
			else
				listedTeam.LayoutOrder = 1 -- everyone else in the back of the bus
			end

			for _, oldEntry in listedTeam.PlayerList:GetChildren() do -- clean out the list to account for people who might've left
				if oldEntry:IsA("Frame") then
					local gamePlayer = game.Players:FindFirstChild(oldEntry.Name)
					if gamePlayer then -- update people's stats while you're here
						-- is this a squadmate on our team?
						if gamePlayer.Team == localPlayer.Team and gamePlayer:GetAttribute("selectedSquad") ~= nil and gamePlayer:GetAttribute("selectedSquad") == localPlayer:GetAttribute("selectedSquad") then
							oldEntry.PlayerName.TextColor3 = Config.squadColor
						end
					else
						oldEntry:Destroy()
					end
				end
			end
		end
	end

	task.wait()

	for _, player in game.Players:GetChildren() do -- go through all players in the players list
		local listedPlayer = teamList[player.Team.Name].PlayerList:FindFirstChild(player.Name) -- does this player have an entry already?
		if not listedPlayer then -- this player does not have an entry
			AddNewEntry(player) -- create a new player entry
		end
	end
end

function SecondsToMMSS(Seconds)
	local SS = Seconds % 60
	local MM = (Seconds - SS) / 60 -- you could also do local MM = math.floor(Seconds / 60)
	return MM..":"..(10 > SS and "0"..SS or SS)
end

RunService.RenderStepped:Connect(function() -- running the system clock or the time left in the match - do not add much to this function as it is performance dependent
	local TimeInUnix = os.time()

	local stringToFormat = "%I:%M %p"

	local result = os.date(stringToFormat, TimeInUnix)

	frame.Topbar.GameTime.Text = result

	if Vars.Timer.Value ~= 0 then -- the timer is being used
		canvas.roundTimer.Visible = true

		if Vars.Timer.Value <= 10 then -- the final countdown
			canvas.roundTimer.TextColor3 = Config.negativeColor
		else -- not the final countdown
			canvas.roundTimer.TextColor3 = Config.defaultColor
		end

		local convertedTime = SecondsToMMSS(Vars.Timer.Value) -- convert the time for text use
		if Vars.roundActive then --we're in a round
			frame.Topbar.GameTime.Text = convertedTime
		end
		canvas.roundTimer.Text = convertedTime
	else
		canvas.roundTimer.Visible = false
	end
end)

-- Connect the remote event
repStats:Connect(UpdateLeaderboard)
UpdateLeaderboard()

frame.Topbar.GameName.Text = workspace.Parent.Name -- a little panache
canvas.roundTimer.TextColor3 = Config.defaultColor