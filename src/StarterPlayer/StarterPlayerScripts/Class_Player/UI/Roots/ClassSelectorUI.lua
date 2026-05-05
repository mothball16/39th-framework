local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local create = Vide.create
local source = Vide.source
local derive = Vide.derive
local indexes = Vide.indexes

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local ClassCard = require(UI.Components.ClassCard)
local MenuActionButton = require(UI.Components.MenuActionButton)

local ASPECT_RATIO = 1.5
local PADDING_SCALE = 0.02

return function(props: {
	factionConfigs: () -> any,
	playerFactionIds: () ->any,
	playerClassKeys: () -> any,
	playerClassIds: () -> any,
	classCountsByFaction: () -> any,

	requestClass: ((classKey: string, classId: string) -> ())?,
})
	local localPlayer = Players.LocalPlayer
	local playerKey = if localPlayer then tostring(localPlayer.UserId) else "0"

	local selectedVariantByClassKey = source({})
	local isOpen = source(false)

	local localFactionId = derive(function()
		return props.playerFactionIds()[playerKey]
	end)
	local localFactionConfig = derive(function()
		return props.factionConfigs()[localFactionId()]
	end)
	local localClassCounts = derive(function()
		return props.classCountsByFaction()[localFactionId()] or {}
	end)
	local localCurrentClassKey = derive(function()
		return props.playerClassKeys()[playerKey]
	end)
	local localCurrentClassId = derive(function()
		return props.playerClassIds()[playerKey]
	end)

	local viewModel = derive(function()
		if not localFactionId() or not localFactionConfig() then
			return nil
		end
		-- build class entries
		local classes = {}
		for classKey, classConfig in pairs(localFactionConfig().Classes) do
			local variants = {}
			for _, variant in ipairs(classConfig.ClassIDs or {}) do
				table.insert(variants, variant.Id)
			end
			local selectedIndex = selectedVariantByClassKey()[classKey]
			if not selectedIndex then
				selectedIndex = 1
				if classKey == localCurrentClassKey() then
					for variantIndex, variantClassId in ipairs(variants) do
						if variantClassId == localCurrentClassId() then
							selectedIndex = variantIndex
							break
						end
					end
				end
			end

			if #variants == 0 then
				selectedIndex = 0
			else
				selectedIndex = math.clamp(selectedIndex, 1, #variants)
			end

			local selectedClassId = variants[selectedIndex]
			local count = localClassCounts()[classKey] or 0
			local limit = classConfig.Limit or 0
			table.insert(classes, {
				classKey = classKey,
				variants = variants,
				classId = selectedClassId or "None",
				selectedVariantIndex = selectedIndex,
				count = count,
				limit = limit,
				isFull = limit > 0 and count >= limit,
				isCurrentKey = localCurrentClassKey() == classKey,
				isCurrentId = localCurrentClassId() == selectedClassId,
			})
		end

		table.sort(classes, function(a, b)
			return a.classKey < b.classKey
		end)

		return {
			factionId = localFactionId,
			currentClassKey = localCurrentClassKey() or "<none>",
			currentClassId = localCurrentClassId() or "<none>",
			classes = classes,
		}
	end)

	local function cycleVariant(classKey: string, offset: number)
		local resolvedViewModel = viewModel()
		if not resolvedViewModel then
			return
		end
		for _, classEntry in ipairs(resolvedViewModel.classes) do
			if classEntry.classKey == classKey then
				local variantCount = #classEntry.variants
				if variantCount <= 1 then
					return
				end

				local currentIndex = classEntry.selectedVariantIndex
				local nextIndex = ((currentIndex - 1 + offset) % variantCount) + 1
				
				-- updates the state in a way that triggers an update
				local nextState = selectedVariantByClassKey()
				nextState[classKey] = nextIndex
				selectedVariantByClassKey(nextState)
				return
			end
		end
	end

	-- stable version of classes in the case of no faction/vm
	local classEntries = derive(function()
		local vm = viewModel()
		if not vm then
			return {}
		end
		return vm.classes
	end)

	-- NOTE TO SELF - item is an individual data entry in classEntries, which comes from viewModel
	-- the info is used to rebuild solely the card for that entry
	-- instead of rebuilding the entire card list
	local cardRows = indexes(classEntries, function(item, i)
		return ClassCard({
				title = function() return item().classKey end,
				classId = function() return item().classId end,
				count = function() return item().count end,
				limit = function() return item().limit end,
				isCurrentKey = function() return item().isCurrentKey end,
				isCurrentId = function() return item().isCurrentId end,

				SelectClass = function()
					local resolvedItem = item()
					if not resolvedItem then
						return
					end
					local isCurrentSelection = resolvedItem.isCurrentKey and resolvedItem.isCurrentId
					if resolvedItem.isFull and not isCurrentSelection then
						return
					end
					if not props.requestClass then
						return
					end
					props.requestClass(resolvedItem.classKey, resolvedItem.classId)
				end,
			})
	end)

	---------------------- [template] ----------------------

	return create "Frame" {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,

		MenuActionButton({
			Position = UDim2.fromScale(0, 0.5),
			Text = "CLASSES",
			OnActivated = function()
				isOpen(true)
			end,
			WindowActive = function()
				return isOpen()
			end,
		}),

		create "Frame" {
			Visible = function() return isOpen() end,
				Name = "ClassSelectorUI",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.55, 1),
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
						Size = UDim2.fromScale(0.1, 0.8),
						BackgroundTransparency = 1,
						Text = "CLOSE",
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = Theme.TextColor,
						TextScaled = true,
						FontFace = Theme.fontH2,
						Activated = function()
							isOpen(false)
						end,
					}
				},

				create "Frame" {
					Name = "ContentLeft",
					Position = UDim2.fromScale(0, 0.1),
					Size = UDim2.fromScale(0.5, 0.9),
					BackgroundTransparency = 1,

					create "UIPadding" {
						PaddingLeft = UDim.new(PADDING_SCALE*2, 0),
						PaddingRight = UDim.new(PADDING_SCALE*2, 0),
						PaddingTop = UDim.new(PADDING_SCALE, 0),
						PaddingBottom = UDim.new(PADDING_SCALE, 0),
					},

					create "TextLabel" {
						Name = "FactionName",
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 0.1),
						BackgroundTransparency = 1,
						Text = function()
							return `{localFactionConfig() and localFactionConfig().Name or "None"}`
						end,
						TextColor3 = Theme.TextColor,
						TextScaled = true,
						FontFace = Theme.fontH2,
					},

					create "ScrollingFrame" {
						LayoutOrder = 4,
						Position = UDim2.fromScale(0, 0.1),
						Size = UDim2.fromScale(1, 0.8),
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
						LayoutOrder = 5,
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						Font = Enum.Font.RobotoMono,
						TextColor3 = Color3.fromRGB(180, 180, 180),
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = function()
							local localViewModel = viewModel()
							if not localViewModel then
								return "No class options available yet."
							end
							if #localViewModel.classes == 0 then
								return "Faction has no classes configured."
							end
							return ""
						end,
					},


				},
				
				
			}
	}
	
end