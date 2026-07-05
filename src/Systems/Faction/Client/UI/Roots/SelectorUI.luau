local State = require("@game/ReplicatedStorage/Systems/Faction/Core/State")
local Enums = require("@game/ReplicatedStorage/Systems/Faction/Core/Enums")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local create, derive, indexes, effect = Vide.create, Vide.derive, Vide.indexes, Vide.effect
local untrack = Vide.untrack
local Theme = require("../Theme")
local ClassCard = require("../Components/Card")
local MenuActionButton = require("../Components/MenuActionButton")
local VariantSelector = require("../Components/VariantSelector")
local GetPlayerSlice = require("@game/ReplicatedStorage/Systems/Faction/Selectors/GetPlayerSliceVide")
local UseVariantSelector = require("@game/ReplicatedStorage/Systems/Faction/Composables/UseVariantSelector")

local ASPECT_RATIO = 1.5
local PADDING_SCALE = 0.02

return function(props: {
	state: State.State,
	userId: string,
	manualButton: boolean,
	isOpen: Vide.Source<boolean>,
	setSelectorOpen: ((open: boolean) -> ()) -> (),
	requestClassVariant: ((classKey: string, variantId: string) -> ()),
	requestVariantApply: ((enable: boolean) -> ())?,
	applyVariantMode: string?,
})
	local player = GetPlayerSlice(props.state, props.userId)
	local selector = UseVariantSelector(player)

	local cardRows = indexes(player.classEntries, function(classEntry)
		local isSelected = derive(function()
			return classEntry().Key == player.classKey()
		end)

		return ClassCard({
			isSelected = isSelected,

			title = function()
				return classEntry().Key or "<no key?>"
			end,
			count = function()
				return player.classCounts()[classEntry().Key] or 0
			end,
			limit = function()
				return classEntry().Limit
			end,
			SelectClass = function()
				local variants = classEntry().Variants
				if #variants == 0 then
					error(`no variants found for class: {classEntry().Key}`)
				end
				local id = if isSelected()
					then (selector.selectedVariant() or variants[1]).Id
					else variants[1].Id
				props.requestClassVariant(classEntry().Key, id)
			end,
		})
	end)

	local _onOpenToggled = effect(function()
		local shouldToggleVariantApply = props.applyVariantMode == Enums.ApplyVariantMode.AfterInteraction
		if props.isOpen() then
			if shouldToggleVariantApply and props.requestVariantApply then
				props.requestVariantApply(false)
			end
		else
			if untrack(selector.dirty) then
				local selected = untrack(selector.selectedVariant)
				local classKey = untrack(player.classKey)
				if selected and classKey then
					props.requestClassVariant(classKey, selected.Id)
				end
				selector.dirty(false)
			end

			if shouldToggleVariantApply and props.requestVariantApply then
				props.requestVariantApply(true)
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
								return "No class options available yet."
							end
							-- cool trick to check if the dictis empty
							if not next(factionConfig.Classes) then
								return "Faction has no classes configured."
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
						Name = "VariantOptions",
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

						VariantSelector {
							title = "Variant",
							titleHeight = 0.5,
							size = UDim2.fromScale(1, 0.25),
							ValueText = function()
								local variant = selector.selectedVariant()
								if not variant then
									return "<no variant selected...>"
								end
								local label = variant.Name or variant.Id
								return `{label} ({selector.variantIndex()}/{#player.variants()})`
							end,
							LeftActivated = function()
								selector.cycleVariant(-1)
							end,
							RightActivated = function()
								selector.cycleVariant(1)
							end,
						},
						create "Frame" {
							LayoutOrder = 5,
							Name = "VariantDescription",
							Position = UDim2.fromScale(0, 0.7),
							Size = UDim2.fromScale(1, 0.4),
							BackgroundTransparency = 0.9,
							BackgroundColor3 = Theme.AccentColor,
							create "TextLabel" {
								Name = "DescriptionText",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.9, 0.85),
								BackgroundTransparency = 1,
								TextColor3 = Theme.TextColor,
								TextTransparency = 0.5,
								TextScaled = true,
								FontFace = Theme.fontNormal,
								RichText = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Top,
								Text = function()
									return if selector.selectedVariant()
										then (
											selector.selectedVariant().Description
											or "Lorem ipsum on the beat yo!\n\n\n(no description)"
										)
										else "<no variant selected...>"
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
