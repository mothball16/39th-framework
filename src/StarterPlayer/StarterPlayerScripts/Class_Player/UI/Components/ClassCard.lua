local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Root = script.Parent.Parent
local Theme = require(Root.Theme)
local Vide = require(Packages.Vide)
local create = Vide.create
local derive = Vide.derive
local source = Vide.source

local Stroke = require(script.Parent.Stroke)


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

	Activated: () -> (),
	PreviousVariant: () -> (),
	NextVariant: () -> (),
})
	local isFull = derive(function()
		return props.limit() > 0 and props.count() >= props.limit()
	end)
	local hoveringOverDetails = source(false)


	local root = create "CanvasGroup" {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,


		create "UIAspectRatioConstraint" {
			AspectRatio = ASPECT_RATIO,
			DominantAxis = Enum.DominantAxis.Width,
		},

		create "Frame" {
			ZIndex = 40,
			Name = "Accents",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			
			create "Frame" {
				Name = "Divider",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -DIVIDER_PX, 0, 0),
				Size = UDim2.new(0, DIVIDER_PX, 1, 0),
				BackgroundColor3 = Theme.TextColor,
				BorderSizePixel = 0,
			},

			create "Frame" {
				Name = "Divider",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -DIVIDER_PX * 3, 0, 0),
				Size = UDim2.new(0, DIVIDER_PX, 1, 0),
				BackgroundColor3 = Theme.TextColor,
				BorderSizePixel = 0,
			},

			create "Frame" {
				Name = "Indicator",
				Size = UDim2.new(0, 6, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundColor3 = function()
					return if isFull() then Theme.ColorError else Theme.AccentColor
				end,
				BorderSizePixel = 0,
			},
		},

		create "Frame" {
			Name = "Content",
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Theme.Background,
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
				TextColor3 = Theme.TextColor,
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
				TextColor3 = Theme.TextColor,
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
				TextColor3 = Theme.TextColor,
				TextScaled = true,

				AutoButtonColor = true,
				Activated = props.Activated,

				create "TextLabel" {
					Name = "SelectText",
					Position = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(0.8, 0, 0.8, 0),
					BackgroundTransparency = 1,
					Text = "SELECT",
					TextColor3 = Theme.TextColor,
					TextScaled = true,
					FontFace = Theme.fontH2,
				}
			},

			create "Frame" {
				Name = "Details",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.4 + 0.3/2, 0),
				Size = UDim2.fromScale(0.2, 0.2),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,

				Stroke({
					Color = Theme.AccentColor,
					Thickness = 2,
					LineJoinMode = Enum.LineJoinMode.Miter,
				}),

				MouseEnter = function()
					hoveringOverDetails(true)
				end,
				MouseLeave = function()
					hoveringOverDetails(false)
				end,

				create "TextLabel" {
					Name = "SelectText",
					Position = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(0.8, 0, 0.8, 0),
					BackgroundTransparency = 1,
					Text = "DETAILS",
					TextColor3 = Theme.TextColor,
					TextScaled = true,
					FontFace = Theme.fontH3,
				}
			},

			create "Frame" {
				ZIndex = 3,
				Name = "VariantSelector",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0.25, 0),
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
					TextColor3 = Theme.TextColor,
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
					TextColor3 = Theme.TextColor,
					TextScaled = true,
					AutoButtonColor = false,
					FontFace = Theme.fontH2,
					Activated = props.PreviousVariant,
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
					TextColor3 = Theme.TextColor,
					TextScaled = true,
					AutoButtonColor = false,
					FontFace = Theme.fontH2,
					Activated = props.NextVariant,
				},
			},
		},

		create "CanvasGroup" {
			ZIndex = 5,
			GroupTransparency = function()
				return if hoveringOverDetails() then 0 else 1
			end,
			Name = "Details",
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			BorderSizePixel = 0,
			BackgroundColor3 = Theme.Background,
			BackgroundTransparency = 0.35,

			create "TextLabel" {
				Name = "DetailsText",
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(0.8, 0, 0.8, 0),
				BackgroundTransparency = 1,
				Text = "details not finished yet son",
				TextColor3 = Theme.TextColor,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				FontFace = Theme.fontNormal,
			},
		}
	}
	return root
end

return ClassCard
