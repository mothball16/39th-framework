--!strict
--[[
handles the positioning and state side effects of ping tags
presentation is handled in the PingTag component
]]

local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")

local useAtom = require("@game/ReplicatedStorage/Packages/vide-charm").useAtom
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local VideRipple = require("@game/ReplicatedStorage/Packages/vide-ripple")

local source = Vide.source
local create = Vide.create
local mount = Vide.mount
local indexes = Vide.indexes
local effect = Vide.effect
local derive = Vide.derive
local cleanup = Vide.cleanup

local UserSettings = require("../Core/UserSettings")
local PingTag = require("../UI/Roots/PingTag")

type PingsGetter = () -> { [string]: Types.PingInfo }

export type PingRenderState = {
	getPingInfo: () -> Types.PingInfo,
	screenPosition: Vide.source<UDim2>,
	visible: Vide.source<boolean>,
	transModifier: Vide.source<number>,
	lifetime: number,
}

local TRANSPARENCY_GOAL = 0.25
local SCALE_GOAL = 1
local PING_READY_TIME = 0.5

local PingTagRenderer = {
	PingStates = {} :: { [string]: PingRenderState },
}

local function numLerp(a: number, b: number, t: number)
	return a + (b - a) * t
end

function PingTagRenderer.Mount(pings: PingsGetter, parent: Instance)
	mount(function()
		local pingSize = useAtom(UserSettings.PingSize)
		pings = useAtom(pings)

		return create "ScreenGui" {
			Name = "AwarePings",
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			DisplayOrder = 10,

			indexes(pings, function(item: () -> Types.PingInfo, key: string)
				local state: PingRenderState = {
					getPingInfo = item,
					screenPosition = source(UDim2.new()),
					visible = source(true),
					transModifier = source(1),
					lifetime = 0
				}

				PingTagRenderer.PingStates[key] = state
				
				local getPingPosition = derive(function(): Vector3
					return item().position
				end)

				local scaleValue, scaleSpring = VideRipple.useSpring(1)
				local transValue, transSpring = VideRipple.useSpring(1)
				effect(function()
					getPingPosition()
					transSpring:setPosition(1)
					transSpring:setGoal(TRANSPARENCY_GOAL)
					scaleSpring:setPosition(2)
					scaleSpring:setGoal(SCALE_GOAL)
				end)

				cleanup(function()
					PingTagRenderer.PingStates[key] = nil
				end)

				return create "CanvasGroup" {
					Name = "PingTag",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = state.screenPosition,
					Size = function()
						local pingSize = pingSize()
						local scale = scaleValue()
						return UDim2.new(
							pingSize.X.Scale * scale,
							pingSize.X.Offset * scale,
							pingSize.Y.Scale * scale,
							pingSize.Y.Offset * scale)
					end,
					BackgroundTransparency = 1,
					Visible = state.visible,
					GroupTransparency = function() return numLerp(transValue(), 1, 1 - state.transModifier()) end,

					PingTag({
						imageId = item().imageId,
						name = item().name,
					}),
				}
			end),
		}
	end, parent)
end

function PingTagRenderer.OnRender(dt: number, mouseLocation: Vector2)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local viewportSize = camera.ViewportSize

	for key, state in pairs(PingTagRenderer.PingStates) do
		local info = state.getPingInfo()
		local screenPoint, onScreen = camera:WorldToViewportPoint(info.position)
		state.screenPosition(UDim2.fromOffset(screenPoint.X, screenPoint.Y))
		state.visible(onScreen)
		state.lifetime += dt

		if onScreen then

			if state.lifetime > PING_READY_TIME then
				local scaleDiff = Vector2.new((mouseLocation.X - screenPoint.X) / viewportSize.X, (mouseLocation.Y - screenPoint.Y) / viewportSize.Y)
				-- expo. decrease transparency so that the intended transparency effect fully applies faster than just at the very center
				local proximityTransFactor = (1 - math.clamp(scaleDiff.Magnitude / UserSettings.HidePingDistance(), 0, 1)) ^ 0.5
				state.transModifier(numLerp(1, UserSettings.HidePingTransModifier(), proximityTransFactor))
			end

		end
	end
end

return PingTagRenderer
