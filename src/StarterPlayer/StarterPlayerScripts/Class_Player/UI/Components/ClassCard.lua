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

local CLASS_TITLE_HEIGHT = 0.35
local CLASS_COUNT_HEIGHT = 0.3

local function ClassCard(props: {
	title: () -> string,
	classId: () -> string,
	count: () -> number,
	limit: () -> number,
	
	isCurrentKey: () -> boolean,
	isCurrentId: () -> boolean,

	SelectClass: () -> (),
})
	local isFull = derive(function()
		return props.limit() > 0 and props.count() >= props.limit()
	end)

	local isSelected = derive(function()
		return props.isCurrentId() and props.isCurrentKey()
	end)



	local actionAccent = derive(function()
		return if isFull() then Theme.ColorError else Theme.AccentColor
	end)

	local hoveringOverDetails = source(false)



	---------------------- [template] ----------------------

	return create "CanvasGroup" {

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
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,

			create "UIPadding" {
				PaddingLeft = UDim.new(0.05, 0),
				PaddingRight = UDim.new(0.05, 0),
				PaddingTop = UDim.new(0.05 / ASPECT_RATIO, 0),
				PaddingBottom = UDim.new(0.05 / ASPECT_RATIO, 0),
			},

			create "TextLabel" {
				Name = "ClassTitle",
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, CLASS_TITLE_HEIGHT, 0),
				BackgroundTransparency = 1,
				Text = function()
					return props.title()
				end,
				TextColor3 = Theme.TextColor,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				FontFace = Theme.fontH1,
			},

			create "TextLabel" {
				Name = "ClassCount",
				Position = UDim2.new(0, 0, CLASS_TITLE_HEIGHT, 0),
				Size = UDim2.new(1, 0, CLASS_COUNT_HEIGHT, 0),
				BackgroundTransparency = 1,
				Text = function()
					local limit = props.limit()
					if limit > 0 then
						return `{props.count()}/{limit}`
					end
					return `{props.count()}/-`
				end,
				TextColor3 = Theme.TextColor,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = Theme.fontNormal,
			},

			create "TextButton" {
				Name = "Select",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, CLASS_TITLE_HEIGHT / 2, 0),
				Size = UDim2.fromScale(0.25, CLASS_TITLE_HEIGHT * 0.8),
				BackgroundColor3 = function()
					if isSelected() then
						return Theme.BackgroundAlt
					end
					return actionAccent()
				end,
				BorderSizePixel = 0,
				TextColor3 = Theme.TextColor,
				TextScaled = true,

				Active = function()
					return not isFull() or isSelected()
				end,
				AutoButtonColor = true,
				Activated = props.SelectClass,

				create "TextLabel" {
					Name = "SelectText",
					Position = UDim2.new(0.5, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Size = UDim2.new(0.8, 0, 0.8, 0),
					BackgroundTransparency = 1,
					Text = function()
						if isSelected() then return "EQUIPPED" end
						return if isFull() then "FULL" else "SELECT"
					end,
					TextColor3 = Theme.TextColor,
					TextScaled = true,
					FontFace = Theme.fontH2,
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
				Text = "details not implemented yet : (",
				TextColor3 = Theme.TextColor,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				FontFace = Theme.fontNormal,
			},
		},
	}
end

return ClassCard
