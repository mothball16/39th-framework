local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create = Vide.create
local StoryButton = require("./StoryButton")

local BUTTON_HEIGHT = 32
local BUTTON_PADDING = 4

local function StoryButtonList(props: {
	actions: { { text: string, onActivated: () -> () } },
})
	local listHeight = #props.actions * BUTTON_HEIGHT + math.max(0, #props.actions - 1) * BUTTON_PADDING

	return create "Frame" {
		Name = "StoryControls",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.15, 0, 0, listHeight + 16),
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,

		create "UIPadding" {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		},

		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, BUTTON_PADDING),
		},

		function()
			local buttons = {}
			for i, action in ipairs(props.actions) do
				buttons[i] = StoryButton({
					layoutOrder = i,
					text = action.text,
					onActivated = action.onActivated,
				})
			end
			return buttons
		end,
	}
end


return StoryButtonList