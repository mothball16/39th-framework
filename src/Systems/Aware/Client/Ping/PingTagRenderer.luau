--!strict
--[[
handles the positioning and state side effects of ping tags
presentation is handled in the PingTag component
]]
local SoundService = game:GetService("SoundService")

local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")

local useAtom = require("@game/ReplicatedStorage/Packages/vide-charm").useAtom
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local VideRipple = require("@game/ReplicatedStorage/Packages/vide-ripple")
local Access = require("@game/ReplicatedStorage/Systems/Aware/Access")

local fx = Access.Assets:FindFirstChild("FX") :: Folder
local pingSound = fx:FindFirstChild("PingSound") :: Sound

local atom = Charm.atom
local create = Vide.create
local mount = Vide.mount
local indexes = Vide.indexes
local effect = Vide.effect
local derive = Vide.derive
local cleanup = Vide.cleanup

local UserSettings = require("../Core/UserSettings")
local PingTag = require("../UI/Components/PingTag")

type PingsGetter = () -> { [string]: Types.PingInfo }

local TRANSPARENCY_GOAL = 0.25
local SCALE_GOAL = 1
local PING_READY_TIME = 0.5

local PingTagRenderer = {}

local function numLerp(a: number, b: number, t: number)
	return a + (b - a) * t
end

function PingTagRenderer.Mount(pings: PingsGetter, parent: Instance, pingClientStates: Types.PingClientStates)
	mount(function()
		local pingSize = useAtom(UserSettings.PingSize)
		pings = useAtom(pings)

		return create "ScreenGui" {
			Name = "AwarePings",
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 10,

			indexes(pings, function(item: () -> Types.PingInfo, key: string)
				local state: Types.PingRenderState = {
					getPingInfo = item,
					screenPosition = atom(UDim2.new()),
					visible = atom(true),
					transModifier = atom(1),
					lifetime = 0,
				}

				pingClientStates[key] = state

				local getPingPosition = derive(function(): Vector3
					return item().position
				end)

				local getName = derive(function(): string
					return item().name
				end)

				local scaleValue, scaleSpring = VideRipple.useSpring(1)
				local transValue, transSpring = VideRipple.useSpring(1)
				local getScreenPosition = useAtom(state.screenPosition)
				local getVisible = useAtom(state.visible)
				local getTransModifier = useAtom(state.transModifier)

				effect(function()
					getPingPosition()
					state.lifetime = 0
					SoundService:PlayLocalSound(pingSound)
					transSpring:setPosition(1)
					scaleSpring:setPosition(2)
					scaleSpring:setGoal(SCALE_GOAL)
				end)

				effect(function()
					transSpring:setGoal(numLerp(TRANSPARENCY_GOAL, 1, 1 - getTransModifier()))
				end)

				cleanup(function()
					pingClientStates[key] = nil
				end)

				return create "CanvasGroup" {
					Name = "PingTag",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = getScreenPosition,
					Size = function()
						local pingSize = pingSize()
						local scale = scaleValue()
						return UDim2.new(
							pingSize.X.Scale * scale,
							pingSize.X.Offset * scale,
							pingSize.Y.Scale * scale,
							pingSize.Y.Offset * scale
						)
					end,
					BackgroundTransparency = 1,
					Visible = getVisible,
					GroupTransparency = transValue,

					PingTag({
						imageId = item().imageId,
						name = getName,
					}),
				}
			end),
		}
	end, parent)
end

function PingTagRenderer.OnRender(dt: number, mouseLocation: Vector2, pingClientStates: Types.PingClientStates)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewportSize = camera.ViewportSize

	for _, state in pairs(pingClientStates) do
		local info = state.getPingInfo()
		local transparencyModifier = 1
		local screenPoint, onScreen = camera:WorldToViewportPoint(info.position)
		state.lifetime += dt

		state.visible(onScreen)
		if not onScreen then
			continue
		end

		-- if pings are stale, just hide them immediately
		if state.lifetime > UserSettings.HidePingsAfterTime() then
			state.transModifier(0)
			continue
		end

		state.screenPosition(UDim2.fromOffset(screenPoint.X, screenPoint.Y))



		if state.lifetime > PING_READY_TIME then
			local scaleDiff = Vector2.new(
				(mouseLocation.X - screenPoint.X) / viewportSize.X,
				(mouseLocation.Y - screenPoint.Y) / viewportSize.Y
			)
			-- expo. decrease transparency so that the intended transparency effect fully applies faster than just at the very center
			local proximityTransFactor = (
				1 - math.clamp(scaleDiff.Magnitude / UserSettings.HidePingDistance(), 0, 1)
			) ^ 0.5

			transparencyModifier *= numLerp(1, UserSettings.HidePingTransModifier(), proximityTransFactor)
		end

		state.transModifier(transparencyModifier)
	end
end

return PingTagRenderer
