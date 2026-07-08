--!strict
--#selene: allow(incorrect_standard_library_use)
local Players = game:GetService("Players")

local Maid = require("@game/ReplicatedStorage/Packages/maid")

local Types = require("../Core/Types")

local TDM = {}

export type Config = {
	ID: string,
	AutoStart: boolean?,
	ScoreLimit: number?,
	AllowSelfKills: boolean?,
	AllowTeamKills: boolean?,
	PlayerSource: any?,
}

function TDM.FindKiller(character: Model?, humanoid: Humanoid?): Player?
	if character then
		local killer = character:FindFirstChild("Killer")
		if killer and killer:IsA("ObjectValue") and killer.Value and killer.Value:IsA("Player") then
			return killer.Value
		end
	end

	if humanoid then
		local creator = humanoid:FindFirstChild("creator")
		if creator and creator:IsA("ObjectValue") and creator.Value and creator.Value:IsA("Player") then
			return creator.Value
		end
	end

	return nil
end

function TDM.ScoreKill(context: Types.ObjectiveContext, config: Config, killer: Player?, victim: Player?): boolean
	if not killer or not victim then
		return false
	end

	if killer == victim and not config.AllowSelfKills then
		return false
	end

	local killerTeam = context.GetTeamId(killer)
	local victimTeam = context.GetTeamId(victim)
	if not killerTeam then
		return false
	end

	if killerTeam == victimTeam and not config.AllowTeamKills then
		return false
	end

	local score = context.AddScore(killerTeam, 1)
	if config.ScoreLimit and score >= config.ScoreLimit then
		context.Complete({ winnerTeam = killerTeam })
	end

	return true
end

local function hookCharacter(
	context: Types.ObjectiveContext,
	config: Config,
	playerMaid: Maid.Maid,
	player: Player,
	character: Model
)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local connection = humanoid.Died:Connect(function()
		TDM.ScoreKill(context, config, TDM.FindKiller(character, humanoid), player)
	end)
	playerMaid:GiveTask(connection)
end

function TDM.build(config: Config): Types.ObjectiveDefinition
	return {
		ID = config.ID,
		Kind = "TDM",
		AutoStart = config.AutoStart,
		OnStart = function(context)
			local playerSource = config.PlayerSource or Players
			local playerMaids = {}

			local function cleanupPlayer(player: Player)
				local playerMaid = playerMaids[player]
				if playerMaid then
					playerMaid:DoCleaning()
					playerMaids[player] = nil
				end
			end

			local function hookPlayer(player: Player)
				cleanupPlayer(player)

				local playerMaid = Maid.new()
				playerMaids[player] = playerMaid
				context.Maid:GiveTask(playerMaid)

				playerMaid:GiveTask(player.CharacterAdded:Connect(function(character)
					hookCharacter(context, config, playerMaid, player, character)
				end))

				if player.Character then
					hookCharacter(context, config, playerMaid, player, player.Character)
				end
			end

			context.Maid:GiveTask(playerSource.PlayerAdded:Connect(function(player)
				hookPlayer(player)
			end))
			context.Maid:GiveTask(playerSource.PlayerRemoving:Connect(function(player)
				cleanupPlayer(player)
			end))

			for _, player in ipairs(playerSource:GetPlayers()) do
				hookPlayer(player)
			end

			return nil
		end,
	}
end

return TDM
