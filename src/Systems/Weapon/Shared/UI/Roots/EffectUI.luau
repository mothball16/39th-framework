local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create
local source = Vide.source
local indexes = Vide.indexes
local effect = Vide.effect
local derive = Vide.derive
local spring = Vide.spring
local untrack = Vide.untrack
local Hitmarker = require("../Components/Hitmarker")
local DamageFlash = require("../Components/DamageFlash")
local SuppressionCanvas = require("../Components/SuppressionCanvas")
local Types = require("../Types")

return function(props: Types.EffectViewProps)
	local showDamage = derive(function()
		return props.activeDamage() > 0
	end)

	local transparency = spring(function()
		return showDamage() and 0.25 or 1
	end, 0.1, 0.1)
	local panelLerpPosition = spring(function()
		return props.panelPosition()
	end, 0.05, 0.5)

	return create "Frame" {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		indexes(props.activeHitmarkers, function(item, index)
			return create "Frame" {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Hitmarker(item().props),
				DamageFlash(item().props, item().damage),
			}
		end),

		SuppressionCanvas({
			factor = props.suppressionFactor,
			minSize = props.suppressionLimit,
		}),

		-- forward-panel, based off the muzzle position
		create "Frame" {
			Name = "ForwardPanel",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = panelLerpPosition,

			create "UIAspectRatioConstraint" {
				AspectRatio = 1,
				DominantAxis = Enum.DominantAxis.Width,
			},

			create "Frame" {
				Name = "DamageIndicator",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.fromScale(1, 0.2),
				create "Frame" {
					Name = "Accent",
					BackgroundTransparency = transparency,
					Size = spring(function()
						return showDamage() and UDim2.new(0.1, 0, 0, 1) or UDim2.fromScale(1, 0, 0, 1)
					end, 0.3, 1),
					-- Position = UDim2.fromScale(0, 0.2)
				},
				create "Frame" {
					Name = "Accent",
					BackgroundTransparency = transparency,
					-- Position = UDim2.fromScale(0.05, 0 ),
					Size = spring(function()
						return showDamage() and UDim2.new(0, 1, 0.4, 0) or UDim2.fromScale(0, 1, 1, 0)
					end, 0.6, 1),
				},
				create "TextLabel" {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(0.9, 0.8),
					Position = UDim2.fromScale(0.05, 0.03),
					Text = function()
						return `{math.floor(props.activeDamage())}`
					end,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextColor3 = Color3.new(1, 1, 1),
					TextTransparency = transparency,
					TextScaled = true,
					FontFace = Font.new("RobotoMono", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
				},
			},
		},
	}
end
