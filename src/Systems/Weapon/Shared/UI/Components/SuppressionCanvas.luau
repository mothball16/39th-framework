local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local VideRipple = require("@game/ReplicatedStorage/Packages/vide-ripple")
local useSpring = VideRipple.useSpring

local Types = require("../Types")
local create = Vide.create
local effect = Vide.effect
local derive = Vide.derive
local spring = Vide.spring

local function numLerp(a: number, b: number, t: number)
	return a + (b - a) * math.clamp(t, 0, 1)
end

return function(props: Types.SuppressionCanvasProps)
	if props.minSize < 0.1 then
		warn("suppression canvas minSize must be greater than 0.1")
		props.minSize = 0.1
	end
	local suppressionCanvasSize = derive(function()
		local mapped = numLerp(40, props.minSize * 10, props.factor())
		return UDim2.fromScale(mapped, mapped)
	end)

	return create "CanvasGroup" {
		GroupTransparency = spring(function()
			return props.factor() > 0.1 and 0 or numLerp(0, 1, 1 - (props.factor() * 10))
		end, 0.25, 1.5),
		Name = "Panel",
		BackgroundTransparency = 1,
		Size = spring(suppressionCanvasSize, 0.1, 1.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),

		create "ImageLabel" {
			Name = "Main",
			BackgroundTransparency = 1,
			Image = "rbxassetid://3552746365",
			Size = UDim2.fromScale(0.1, 0.1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = Color3.fromRGB(0, 0, 0),
		},

		create "Frame" {
			Name = "BottomBorder",
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			Size = UDim2.fromScale(1, 0.46),
			Position = UDim2.fromScale(0, 1),
		},

		create "Frame" {
			Name = "TopBorder",
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			Size = UDim2.fromScale(1, 0.46),
			Position = UDim2.fromScale(0, 0),
		},

		create "Frame" {
			Name = "LeftBorder",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			Size = UDim2.fromScale(0.46, 0.1),
			Position = UDim2.fromScale(0, 0.5),
		},

		create "Frame" {
			Name = "RightBorder",
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			Size = UDim2.fromScale(0.46, 0.1),
			Position = UDim2.fromScale(1, 0.5),
		},
	}
end
