local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Root = script.Parent.Parent
local Theme = require(Root.Theme)
local Vide = require(Packages.Vide)
local create = Vide.create
local derive = Vide.derive

local SLAB = Color3.fromRGB(14, 14, 14)
local STRUCTURE = Color3.fromRGB(255, 255, 255)

local DIVIDER_PX = 3
local ASPECT_RATIO = 4

local function ClassCard(props: {
	overlayFrameTransparency: number,
	overlayFrameColor: Color3,
	title: string,
	count: () -> number,
	limit: () -> number,
	variants: () -> {string},
	selectedVariantIndex: () -> number,

	isCurrent: () -> boolean,
	Activated: () -> (),
	PreviousVariant: () -> (),
	NextVariant: () -> (),
})
	local isFull = derive(function()
		return props.limit() > 0 and props.count() >= props.limit()
	end)

	local root = create "CanvasGroup" {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = SLAB,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,

		create "UIAspectRatioConstraint" {
			AspectRatio = ASPECT_RATIO,
			DominantAxis = Enum.DominantAxis.Width,
		},

		create "Frame" {
			ZIndex = 4,
			Name = "Accents",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			
			create "Frame" {
				Name = "Divider",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -DIVIDER_PX, 0, 0),
				Size = UDim2.new(0, DIVIDER_PX, 1, 0),
				BackgroundColor3 = STRUCTURE,
				BorderSizePixel = 0,
			},

			create "Frame" {
				Name = "Divider",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -DIVIDER_PX * 3, 0, 0),
				Size = UDim2.new(0, DIVIDER_PX, 1, 0),
				BackgroundColor3 = STRUCTURE,
				BorderSizePixel = 0,
			},

			create "Frame" {
				Name = "Indicator",
				Size = UDim2.new(0, 6, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundColor3 = if isFull() then Theme.ColorError else Theme.AccentColor,
				BorderSizePixel = 0,
			},
		},

		create "Frame" {
			Name = "Content",
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = SLAB,
			BorderSizePixel = 0,

			create "UIPadding" {
				PaddingLeft = UDim.new(0.05, 0),
				PaddingRight = UDim.new(0.05, 0),
				PaddingTop = UDim.new(0.05/ASPECT_RATIO, 0),
				PaddingBottom = UDim.new(0.05/ASPECT_RATIO, 0),
			},

			create "TextLabel" {
				Name = "ClassTitle",
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0.4, 0),
				BackgroundTransparency = 1,
				Text = string.upper(props.title),
				TextColor3 = STRUCTURE,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				FontFace = Theme.fontH1,
			},
			create "TextLabel" {
				Name = "ClassCount",
				Position = UDim2.new(0, 0, 0.4, 0),
				Size = UDim2.new(1, 0, 0.3, 0),
				BackgroundTransparency = 1,
				Text = `{props.count()}/{props.limit()}`,
				TextColor3 = STRUCTURE,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = Theme.fontNormal,
			},

			create "TextButton" {
				Name = "Select",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.4/2, 0),
				Size = UDim2.fromScale(0.25, 0.35),
				BackgroundColor3 = Theme.AccentColor,
				BorderSizePixel = 0,
				TextColor3 = STRUCTURE,
				TextScaled = true,

				create "TextLabel" {
					Name = "SelectText",
					Position = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(0.8, 0, 0.8, 0),
					BackgroundTransparency = 1,
					Text = "SELECT",
					TextColor3 = STRUCTURE,
					TextScaled = true,
					FontFace = Theme.fontH3,
				}
			},

			create "Frame" {
				Name = "Select",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.35 + 0.25/2, 0),
				Size = UDim2.fromScale(0.2, 0.2),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,

				create "UIStroke" {
					Color = Theme.AccentColor,
					Thickness = 2,
				},

				create "TextLabel" {
					Name = "SelectText",
					Position = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(0.8, 0, 0.8, 0),
					BackgroundTransparency = 1,
					Text = "DETAILS",
					TextColor3 = STRUCTURE,
					TextScaled = true,
					FontFace = Theme.fontH3,
				}
			},
		},

		create "Frame" {
			ZIndex = 3,
			Name = "VariantSelector",
			Position = UDim2.new(0, DIVIDER_PX * 3, 1, 0),
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.new(1, - DIVIDER_PX * 8, 0.25, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			create "TextLabel" {
				Name = "ClassVariants",
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0.8, 0, 0.88, 0),
				BackgroundTransparency = 1,
				RichText = true,
				Text = `<i>placeholder1 | polder2 | <b>placeholder3</b> | placeholder4</i>`,
				TextColor3 = STRUCTURE,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				FontFace = Theme.fontNormal,
			},

			create "TextButton" {
				Name = "PreviousVariant",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromScale(0.05, 0.75),
				BackgroundColor3 = Theme.BackgroundAlt,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Text = "<",
				TextColor3 = STRUCTURE,
				TextScaled = true,
				AutoButtonColor = false,
				FontFace = Theme.fontH2,
				Activated = props.Activated,
			},

			create "TextButton" {
				Name = "NextVariant",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromScale(0.05, 0.75),
				BackgroundColor3 = Theme.BackgroundAlt,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Text = ">",
				TextColor3 = STRUCTURE,
				TextScaled = true,
				AutoButtonColor = false,
				FontFace = Theme.fontH2,
				Activated = props.Activated,
			},
		},
	}
	return root
end

return ClassCard
