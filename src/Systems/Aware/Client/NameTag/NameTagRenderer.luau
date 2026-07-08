--!strict
const Players = game:GetService("Players")
--[[
handles the positioning and state side effects of name tags
presentation is handled in the NameTag component
]]
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Maid = require("@game/ReplicatedStorage/Packages/maid")
local useAtom = require("@game/ReplicatedStorage/Packages/vide-charm").useAtom

local mount = Vide.mount
local create = Vide.create
local indexes = Vide.indexes
local derive = Vide.derive
local cleanup = Vide.cleanup
local source = Vide.source

local PlayerKey = require("@game/ReplicatedStorage/Systems/Aware/Core/PlayerKey")
local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local NameTag = require("../UI/Roots/NameTag")
local UserSettings = require("../Core/UserSettings")

type TeamValuesGetter = () -> Types.OwnedValuesByKey

export type NameRenderState = {
	playerKey: string,
	screenPosition: Vide.source<UDim2>,
	visible: Vide.source<boolean>,
}

local HEAD_OFFSET = Vector3.new(0, 1.5, 0)

local NameTagRenderer = {
	NameTagStates = {} :: { [string]: NameRenderState },
}

local function getPlayerHeadPos(player: Player): Vector3?
	local headPart = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if not headPart then
		return nil
	end
	return headPart.Position
end

local function hookHealth(player: Player, health: Vide.source<number>, maxHealth: Vide.source<number>): () -> ()
	local maid = Maid.new()

	local function hookHumanoid(humanoid: Humanoid)
		health(humanoid.Health)
		maxHealth(humanoid.MaxHealth)

		humanoid:GetPropertyChangedSignal("Health"):Connect(function()
			health(humanoid.Health)
		end)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
			maxHealth(humanoid.MaxHealth)
		end)
	end

	maid:GiveTask(player.CharacterAdded:Connect(function(char)
		hookHumanoid(char:WaitForChild("Humanoid") :: Humanoid)
	end))

	maid:GiveTask(player.CharacterRemoving:Connect(function()
		health(0)
		maxHealth(100)
	end))

	if player.Character then
		local humanoid = player.Character:FindFirstChild("Humanoid") :: Humanoid?
		if humanoid then
			hookHumanoid(humanoid)
		end
	end

	return function()
		maid:Destroy()
	end
end

function NameTagRenderer.Mount(teamValues: TeamValuesGetter, parent: Instance)
	mount(function()
		teamValues = useAtom(teamValues)
        local nameTagSize = useAtom(UserSettings.NameTagSize)
        local nameTagTransparency = useAtom(UserSettings.NameTagTransparency)
        local showOwnNameTag = useAtom(UserSettings.ShowOwnNameTag)

		return create "ScreenGui" {
			Name = "AwareNameTags",
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 9,

			indexes(teamValues, function(item: () -> Types.OwnedValues, playerKey: string): CanvasGroup?
				local player = PlayerKey.FromPlayerKey(playerKey)
				if not player then
					return nil
				end

                if not showOwnNameTag() and player == Players.LocalPlayer then
                    return nil
                end
				local state: NameRenderState = {
					playerKey = playerKey,
					screenPosition = source(UDim2.new()),
					visible = source(false),
				}

				NameTagRenderer.NameTagStates[playerKey] = state

				local getNameTag = derive(function(): string
					return item().NameTag
				end)

				local health = source(100)
				local maxHealth = source(100)
				local unhookHealth = hookHealth(player, health, maxHealth)

				cleanup(function()
					unhookHealth()
					NameTagRenderer.NameTagStates[playerKey] = nil
				end)


				return create "CanvasGroup" {
                    GroupTransparency = nameTagTransparency,
					Name = "NameTag",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = state.screenPosition,
					Size = function() return UDim2.fromOffset(200, nameTagSize()) end,
					BackgroundTransparency = 1,
					Visible = state.visible,

					NameTag({
						nameTag = getNameTag,
						health = health,
						maxHealth = maxHealth,
						textSize = nameTagSize,
					}),
				}
			end),
		}
	end, parent)
end

function NameTagRenderer.OnRender()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	for playerKey, state in NameTagRenderer.NameTagStates do
		local player = PlayerKey.FromPlayerKey(playerKey)
		local headPos = if player then getPlayerHeadPos(player) else nil
		if not headPos then
			state.visible(false)
			continue
		end

		local screenPoint, onScreen = camera:WorldToViewportPoint(headPos + HEAD_OFFSET)
		state.visible(onScreen)
		if onScreen then
			state.screenPosition(UDim2.fromOffset(screenPoint.X, screenPoint.Y))
		end
	end
end

return NameTagRenderer
