local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Types = require(Access.Framework.Core:WaitForChild("Types"))

local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local create, source, derive, indexes, effect = Vide.create, Vide.source, Vide.derive, Vide.indexes, Vide.effect

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Card = require(UI.Components.Card)
local MenuActionButton = require(UI.Components.MenuActionButton)
local VariantSelector = require(UI.Components.VariantSelector)

local ASPECT_RATIO = 1.5
local PADDING_SCALE = 0.02

return function(props: {
	factionConfigs: () -> any,
	playerByFactionId: () -> any,
	playerByClassKey: () -> any,
	playerByClassId: () -> any,
	classCountByFaction: () -> any,
	startOpen: boolean,
	requestClass: ((classKey: string, classId: string) -> ())?,
	requestClassActive: ((active: boolean) -> ())?,
})
	local localPlayer = Players.LocalPlayer
	local playerKey = if localPlayer then tostring(localPlayer.UserId) else "0"

	local variantIndexByClassKey = source({})
	local isOpen = source(props.startOpen)


	local myFactionId: () -> string = derive(function()
		return props.playerByFactionId()[playerKey]
	end)

	local myClassCounts: () -> { [string]: number } = derive(function()
		return props.classCountByFaction()[myFactionId()] or {}
	end)

	local myClassKey: () -> string = derive(function()
		return props.playerByClassKey()[playerKey]
	end)

	local myClassId: () -> string = derive(function()
		return props.playerByClassId()[playerKey]
	end)

	local myFactionConfig: () -> Types.FactionConfig = derive(function()
		return props.factionConfigs()[myFactionId()]
	end)

	local myClassConfig: () -> Types.ClassConfig = derive(function()
		if not myFactionConfig() or not myClassKey() then
			return nil
		end
		return myFactionConfig().Classes[myClassKey()]
	end)

	local myVariantConfig: () -> Types.ClassVariant = derive(function()
		if not myClassConfig() or not myClassId() then
			return nil
		end

		local variantIndex = variantIndexByClassKey()[myClassKey()]
		if not variantIndex then
			variantIndex = 1
			for i, variant in ipairs(myClassConfig().ClassIDs) do
				if variant.Id == myClassId() then
					variantIndex = i
					break
				end
			end
		end

		variantIndex = math.clamp(variantIndex, 1, #myClassConfig().ClassIDs)
		return myClassConfig().ClassIDs[variantIndex]
	end)

	local function getSelectedVariantIndex(classKey: string, classIDs: { Types.ClassVariant }): number
		local id = variantIndexByClassKey()[classKey]
		if not id then
			id = 1
			if classKey == myClassKey() then
				local currentId = myClassId()
				for i, variant in ipairs(classIDs) do
					if variant.Id == currentId then
						id = i
						break
					end
				end
			end
		end
		return math.clamp(id, 1, #classIDs)
	end

	local function cycleVariant(classKey: string, offset: number)
		local classIDs = myFactionConfig().Classes[classKey].ClassIDs
		local variantCount = #classIDs
		if variantCount <= 1 then
			return
		end

		local currentIndex = getSelectedVariantIndex(classKey, classIDs)
		local nextIndex = ((currentIndex - 1 + offset) % variantCount) + 1

		-- update the local state (gotta do it like this cause of how updating works with vide)
		local nextState = table.clone(variantIndexByClassKey())
		nextState[classKey] = nextIndex
		variantIndexByClassKey(nextState)
	end

	-- map faction config classes to a table for indexes to iterate over
	-- this runs only when myFactionConfig() changes so its not that expensive
	local classEntries = derive(function()
		local classes = {}
		if not myFactionConfig() then
			return classes
		end

		for key, config in pairs(myFactionConfig().Classes) do
			local entry = table.clone(config)
			entry.Key = key
			table.insert(classes, entry)
		end
		return classes
	end)

	local cardRows = indexes(classEntries, function(item, I)
		-- not sure if this needs to be derived - look into how vide indexes works
		local variantIndex = derive(function()
			return getSelectedVariantIndex(item().Key, item().ClassIDs)
		end)

		return Card({
			title = function()
				return item().Key or "<no key?>"
			end,
			classId = function()
				return item().ClassIDs[variantIndex()].Id
			end,
			count = function()
				return myClassCounts()[item().Key] or 0
			end,
			limit = function()
				return item().Limit
			end,
			isSelected = function()
				return myClassKey() == item().Key
			end,
			
			SelectClass = function()
				if not props.requestClass then
					return
				end
				props.requestClass(item().Key, item().ClassIDs[variantIndex()].Id)
			end,
		})
	end)

	local onOpenToggled = effect(function()
		if isOpen() then
			-- stub
			
		else
			if props.applyClass then
				props.applyClass()
			end
		end
	end)
	---------------------- [template] ----------------------

	return create "Frame" {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		MenuActionButton({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 5, 1, -5),
			Text = "class",
			OnActivated = function()
				isOpen(true)
			end,
			WindowActive = function()
				return isOpen()
			end,
		}),

		create "TextButton" {
			Name = "ModalToggler",
			Modal = function()
				return isOpen()
			end,
		},
		create "Frame" {
			Visible = function()
				return isOpen()
			end,
			Name = "SelectorUI",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.4, 1),
			BackgroundColor3 = Theme.Background,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			BorderColor3 = Theme.AccentColor,

			create "UIAspectRatioConstraint" {
				AspectRatio = ASPECT_RATIO,
				DominantAxis = Enum.DominantAxis.Width,
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
						isOpen(false)
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
				},

				create "TextLabel" {
					Name = "FactionName",
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 0.1),
					BackgroundTransparency = 1,
					Text = function()
						return `{myFactionConfig() and myFactionConfig().Name or "<no faction>"}`
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
						TextXAlignment = Enum.TextXAlignment.Left,
						TextScaled = true,
						FontFace = Theme.fontNormal,
						Text = function()
							if not myFactionConfig() then
								return "No class options available yet."
							end
							-- cool trick to check if the dictis empty
							if not next(myFactionConfig().Classes) then
								return "Faction has no classes configured."
							end
							return ""
						end,
					},

					create "Frame" {
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
								return if myVariantConfig()
									then (
										myVariantConfig().Description
										or "Lorem ipsum on the beat yo!\n\n\n(no description)"
									)
									else "<no class selected...>"
							end,
						},
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
							Padding = UDim.new(0, 0),
						},

						VariantSelector {
							title = "Variant",
							titleHeight = 0.5,
							size = UDim2.fromScale(1, 0.25),
							ValueText = function()
								if not myClassConfig() or not myVariantConfig() then
									return "<no variant selected...>"
								end
								local classIDs = myClassConfig().ClassIDs
								local variantIndex = getSelectedVariantIndex(myClassKey(), classIDs)
								
								return `{myVariantConfig().Name} ({variantIndex}/{#classIDs})` or "<no variant name...>"
							end,
							LeftActivated = function()
								cycleVariant(myClassKey(), -1)
							end,
							RightActivated = function()
								cycleVariant(myClassKey(), 1)
							end,
						},

						-- VariantSelector {
						-- 	title = "Uniform",
						-- 	titleHeight = 0.5,
						-- 	size = UDim2.fromScale(1, 0.25),
						-- 	ValueText = function()
						-- 		return `temp` or "<no uniform name...>"
						-- 	end,
						-- },
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
