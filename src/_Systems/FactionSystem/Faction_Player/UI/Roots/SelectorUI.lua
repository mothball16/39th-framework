local Types = require("@game/ReplicatedStorage/Faction_Framework/Core/Types")
local State = require("@game/ReplicatedStorage/Faction_Framework/Core/State")
local Enums = require("@game/ReplicatedStorage/Faction_Framework/Core/Enums")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create, source, derive, indexes, effect = Vide.create, Vide.source, Vide.derive, Vide.indexes, Vide.effect

local Theme = require("../Theme")
local Card = require("../Components/Card")
local MenuActionButton = require("../Components/MenuActionButton")
local ClassSelector = require("../Components/ClassSelector")
local usePlayerSlice = require("../Logic/usePlayerSlice")

local ASPECT_RATIO = 1.5
local PADDING_SCALE = 0.02

return function(props: {
	state: State.State,
	userId: string,
	manualButton: boolean,
	isOpen: Vide.Source<boolean>,
	setSelectorOpen: ((open: boolean) -> ()) -> (),
	requestGroupClass: ((group: string, class: string) -> ()),
	requestClassApply: ((enable: boolean) -> ())?,
	applyClassMode: string?,
})
	local player = usePlayerSlice(props.state, props.userId)
	local dirty = false
	local classIndex = source(1)

	effect(function()
		player.groupKey()
		classIndex(1)
	end)

	local mySelectedClass: () -> Types.ClassDescriptor? = derive(function()
		local classes = player.classes()
		if #classes == 0 then
			return nil
		end
		return classes[math.clamp(classIndex(), 1, #classes)]
	end)

	local function cycleClass(offset: number)
		local classes = player.classes()
		if #classes <= 1 then
			return
		end
		local nextIndex = ((classIndex() - 1 + offset) % #classes) + 1
		classIndex(nextIndex)
		dirty = true
	end

	-- map faction config groups to a table for indexes to iterate over
	-- this runs only when factionConfig() changes so its not that expensive
	local groupEntries = derive(function()
		local groups = {}
		local factionConfig = player.factionConfig()
		if not factionConfig then
			return groups
		end

		for key, config in pairs(factionConfig.Groups) do
			local entry = table.clone(config)
			entry.Key = key
			table.insert(groups, entry)
		end
		return groups
	end)

	local cardRows = indexes(groupEntries, function(item, I)
		return Card({
			title = function()
				return item().Key or "<no key?>"
			end,
			classId = function()
				local classes = item().Classes
				if #classes == 0 then
					return ""
				end
				local index = if item().Key == player.groupKey() then classIndex() else 1
				return classes[math.clamp(index, 1, #classes)].Id
			end,
			count = function()
				return player.groupCounts()[item().Key] or 0
			end,
			limit = function()
				return item().Limit
			end,
			isSelected = function()
				return player.groupKey() == item().Key
			end,
			
			SelectClass = function()
				local classes = item().Classes
				if #classes == 0 then
					return
				end
				local index = if item().Key == player.groupKey() then classIndex() else 1
				props.requestGroupClass(item().Key, classes[math.clamp(index, 1, #classes)].Id)
			end,
		})
	end)

	local _onOpenToggled = effect(function()
		local shouldToggleClassApply = props.applyClassMode == Enums.ApplyClassMode.AfterInteraction
		if props.isOpen() then
			if shouldToggleClassApply and props.requestClassApply then
				props.requestClassApply(false)
			end
		else
			if dirty then
				local classes = player.classes()
				local groupKey = player.groupKey()
				if #classes > 0 and groupKey then
					local index = math.clamp(classIndex(), 1, #classes)
					props.requestGroupClass(groupKey, classes[index].Id)
				end
				dirty = false
			end

			if shouldToggleClassApply and props.requestClassApply then
				props.requestClassApply(true)
			end
		end
	end)
	---------------------- [template] ----------------------

	return create "Frame" {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		Vide.show(function() return props.manualButton end, function()
			return MenuActionButton({
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 5, 1, -5),
				Text = "class",
				OnActivated = function()
					props.setSelectorOpen(true)
				end,
				WindowActive = function()
					return props.isOpen()
				end,
			})
		end),
		
		create "TextButton" {
			Name = "ModalToggler",
			Modal = function()
				return props.isOpen()
			end,
		},
		create "Frame" {
			Visible = true,--function()
				--return props.isOpen()
			--end,
			Name = "SelectorUI",
			AnchorPoint = Vide.spring(function() return if props.isOpen() then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 0) end, 0.25),
			Position = Vide.spring(function() return if props.isOpen() then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 1) end, 0.25),
			Size = UDim2.fromScale(0.4, 1),
			BackgroundColor3 = Theme.Background,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			BorderColor3 = Theme.AccentColor,
			
			

			create "UIAspectRatioConstraint" {
				AspectRatio = ASPECT_RATIO,
				DominantAxis = Enum.DominantAxis.Width,
			},
			create "UIGradient" {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 0.7),
				}),
			},
			create "Frame" {
				Name = "Header",
				Size = UDim2.fromScale(1, 0.1),
				BackgroundColor3 = Theme.AccentColor,

				create "UIPadding" {
					PaddingLeft = UDim.new(PADDING_SCALE, 0),
					PaddingRight = UDim.new(PADDING_SCALE, 0),
					PaddingTop = UDim.new(0.1, 0),
					PaddingBottom = UDim.new(0.1, 0),
				},

				create "TextLabel" {
					Name = "HeaderText",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "CLASSES",
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = Theme.TextColor,
					TextScaled = true,
					FontFace = Theme.fontH1,
				},

				create "TextButton" {
					Name = "CloseButton",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromScale(0.3, 0.8),
					BackgroundTransparency = 1,
					Text = "SAVE & CLOSE",
					TextXAlignment = Enum.TextXAlignment.Right,
					TextColor3 = Theme.TextColor,
					TextScaled = true,
					FontFace = Theme.fontH2,
					Activated = function()
						props.setSelectorOpen(false)
					end,
				},
			},

			create "Frame" {
				Name = "Content",
				Position = UDim2.fromScale(0, 0.1),
				Size = UDim2.fromScale(1, 0.9),
				BackgroundTransparency = 1,

				create "UIPadding" {
					PaddingLeft = UDim.new(PADDING_SCALE, 0),
					PaddingRight = UDim.new(PADDING_SCALE, 0),
					PaddingTop = UDim.new(PADDING_SCALE, 0),
					PaddingBottom = UDim.new(PADDING_SCALE, 0),
				},

				create "Frame" {
					Name = "Divider",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.15),
					Size = UDim2.new(0, 1, 0.8, 0),
					BackgroundColor3 = Theme.TextColor,
					BackgroundTransparency = 0.8,
					BorderSizePixel = 0,

					create "UIGradient" {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(0.5, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
					},
				},

				create "TextLabel" {
					Name = "FactionName",
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 0.1),
					BackgroundTransparency = 1,
					Text = function()
						local factionConfig = player.factionConfig()
						return `{factionConfig and factionConfig.Name or "<no faction>"}`
					end,
					TextColor3 = Theme.TextColor,
					TextScaled = true,
					FontFace = Theme.fontH2,
				},

				create "Frame" {
					Name = "ContentLeft",
					Position = UDim2.fromScale(0, 0.1),
					Size = UDim2.fromScale(0.475, 0.9),
					BackgroundTransparency = 1,

					create "ScrollingFrame" {
						Name = "ClassList",
						LayoutOrder = 4,
						Position = UDim2.fromScale(0, 0.05),
						Size = UDim2.fromScale(1, 0.6),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						CanvasSize = UDim2.new(0, 0, 0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						ScrollBarThickness = 6,
						VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,

						create "UIListLayout" {
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, 0),
						},
						function()
							return cardRows()
						end,
					},

					create "TextLabel" {
						Name = "NoClassesText",
						LayoutOrder = 5,
						Size = UDim2.fromScale(1, 0.1),
						BackgroundTransparency = 1,
						TextColor3 = Color3.fromRGB(180, 180, 180),
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						TextScaled = true,
						FontFace = Theme.fontNormal,
						Text = function()
							local factionConfig = player.factionConfig()
							if not factionConfig then
								return "No group options available yet."
							end
							-- cool trick to check if the dictis empty
							if not next(factionConfig.Groups) then
								return "Faction has no groups configured."
							end
							return ""
						end,
					},

				},

				create "Frame" {
					Name = "ContentRight",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0.1),
					Size = UDim2.fromScale(0.475, 0.9),
					BackgroundTransparency = 1,

					create "Frame" {
						Name = "ClassOptions",
						LayoutOrder = 4,
						Position = UDim2.fromScale(0, 0.05),
						Size = UDim2.fromScale(1, 0.6),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,

						create "UIListLayout" {
							FillDirection = Enum.FillDirection.Vertical,
							HorizontalAlignment = Enum.HorizontalAlignment.Left,
							VerticalAlignment = Enum.VerticalAlignment.Top,
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0.05, 0),
						},

						ClassSelector {
							title = "Class",
							titleHeight = 0.5,
							size = UDim2.fromScale(1, 0.25),
							ValueText = function()
								local class = mySelectedClass()
								if not class then
									return "<no class selected...>"
								end
								local label = class.Name or class.Id
								return `{label} ({classIndex()}/{#player.classes()})`
							end,
							LeftActivated = function()
								cycleClass(-1)
							end,
							RightActivated = function()
								cycleClass(1)
							end,
						},
						create "Frame" {
							LayoutOrder = 5,
							Name = "ClassDescription",
							Position = UDim2.fromScale(0, 0.7),
							Size = UDim2.fromScale(1, 0.25),
							BackgroundTransparency = 0.9,
							BackgroundColor3 = Theme.AccentColor,
							create "TextLabel" {
								Name = "DescriptionText",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.8, 0.8),
								BackgroundTransparency = 1,
								TextColor3 = Theme.TextColor,
								TextTransparency = 0.5,
								TextScaled = true,
								FontFace = Theme.fontNormal,
								RichText = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Top,
								Text = function()
									return if mySelectedClass()
										then (
											mySelectedClass().Description
											or "Lorem ipsum on the beat yo!\n\n\n(no description)"
										)
										else "<no class selected...>"
								end,
							},
						},
					},

					create "ImageLabel" {
						Name = "WorkInProgress",
						Position = UDim2.fromScale(0, 0.6),
						Size = UDim2.fromScale(1, 0.3),
						BackgroundTransparency = 1,
						ImageTransparency = 0.5,
						Image = "rbxassetid://116689120229507",
						ScaleType = Enum.ScaleType.Fit,
					},

					create "TextLabel" {
						Name = "WorkInProgressText",
						Position = UDim2.fromScale(0, 0.9),
						Size = UDim2.fromScale(1, 0.05),
						BackgroundTransparency = 1,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						FontFace = Theme.fontNormal,
						Text = "more options soon...",
						TextTransparency = 0.5,
						TextColor3 = Theme.TextColor,
						TextScaled = true,
					},
				},
			},
		}
	}
end
