local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Root = script.Parent.Parent
local Theme = require(Root.Theme)
local Vide = require(Packages.Vide)
local create = Vide.create
local derive = Vide.derive

local DIVIDER_PX = 3
local ASPECT_RATIO = 6
local CONTENT_PADDING_X = 0.05
local CONTENT_PADDING_Y = 0.1
local TEXT_REGION_WIDTH = 0.75
local CLASS_TITLE_HEIGHT = 0.52
local CLASS_COUNT_HEIGHT = 0.4
local SELECT_HEIGHT = 0.4

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

	local buttonColor = derive(function()
		if isSelected() then
			return Theme.BackgroundAlt
		end
		return actionAccent()
	end)

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
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Background,
			BackgroundTransparency = 0.16,
			BorderSizePixel = 0,
			create "Frame" {
				Name = "LayoutRegion",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(CONTENT_PADDING_X, CONTENT_PADDING_Y),
				Size = UDim2.fromScale(1 - CONTENT_PADDING_X * 2, 1 - CONTENT_PADDING_Y * 2),

				create "TextLabel" {
					Name = "ClassTitle",
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(TEXT_REGION_WIDTH, CLASS_TITLE_HEIGHT),
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
					Position = UDim2.fromScale(0, CLASS_TITLE_HEIGHT),
					Size = UDim2.fromScale(TEXT_REGION_WIDTH, CLASS_COUNT_HEIGHT),
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
					Position = UDim2.fromScale(1, SELECT_HEIGHT * 0.5),
					Size = UDim2.fromScale(1 - TEXT_REGION_WIDTH, SELECT_HEIGHT),
					BackgroundColor3 = buttonColor,
					BorderSizePixel = 0,
					AutoButtonColor = true,
					Active = function()
						return not isFull() or isSelected()
					end,
					Activated = props.SelectClass,


					create "TextLabel" {
						Name = "SelectText",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.85, 0.85),
						BackgroundTransparency = 1,
						Text = function()
							if isSelected() then
								return "EQUIPPED"
							end
							return if isFull() then "FULL" else "SELECT"
						end,
						TextColor3 = Theme.TextColor,
						TextScaled = true,
						FontFace = Theme.fontH2,
					},
				},
			},
		},
	}
end

return ClassCard
