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
local VariantSelector = require(UI.Components.VariantSelector)

local ASPECT_RATIO = 1.5
local PADDING_SCALE = 0.02

return function(props: {
	factionConfigs: () -> any,
	playerFactionIds: () ->any,
	playerClassKeys: () -> any,
	playerClassIds: () -> any,
	classCountsByFaction: () -> any,
	startOpen: boolean,
	requestClass: ((classKey: string, classId: string) -> ())?,
})
	local localPlayer = Players.LocalPlayer
	local playerKey = if localPlayer then tostring(localPlayer.UserId) else "0"

	local variantByClassKey = source({})
	local isOpen = source(props.startOpen)

	local myFactionId = derive(function()
		return props.playerFactionIds()[playerKey]
	end)
	local myFactionConfig = derive(function()
		return props.factionConfigs()[myFactionId()]
	end)
	local myClassCounts = derive(function()
		return props.classCountsByFaction()[myFactionId()] or {}
	end)
	local myClassKey = derive(function()
		return props.playerClassKeys()[playerKey]
	end)
	local myClassId = derive(function()
		return props.playerClassIds()[playerKey]
	end)
	local myVariantConfig = derive(function()
		if not myFactionConfig() or not myClassKey() or not myClassId() then
			return nil
		end
		local class = myFactionConfig().Classes[myClassKey()]
		if not class or not class.ClassIDs or #class.ClassIDs == 0 then
			return nil
		end

		local variantIndex = variantByClassKey()[myClassKey()]
		if not variantIndex then
			variantIndex = 1
			for i, variant in ipairs(class.ClassIDs) do
				if variant.Id == myClassId() then
					variantIndex = i
					break
				end
			end
		end

		variantIndex = math.clamp(variantIndex, 1, #class.ClassIDs)
		return class.ClassIDs[variantIndex]
	end)

	local viewModel = derive(function()
		if not myFactionId() or not myFactionConfig() then
			return nil
		end
		-- build class entries
		local classes = {}
		for classKey, classConfig in pairs(myFactionConfig().Classes) do
			local variants = {}
			for _, variant in ipairs(classConfig.ClassIDs or {}) do
				table.insert(variants, variant.Id)
			end
			local selectedIndex = variantByClassKey()[classKey]
			if not selectedIndex then
				selectedIndex = 1
				if classKey == myClassKey() then
					for variantIndex, variantClassId in ipairs(variants) do
						if variantClassId == myClassId() then
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
			local count = myClassCounts()[classKey] or 0
			local limit = classConfig.Limit or 0
			table.insert(classes, {
				classKey = classKey,
				variants = variants,
				classId = selectedClassId or "None",
				selectedVariantIndex = selectedIndex,
				count = count,
				limit = limit,
				isFull = limit > 0 and count >= limit,
				isCurrentKey = myClassKey() == classKey,
				isCurrentId = myClassId() == selectedClassId,
			})
		end


		return {
			factionId = myFactionId,
			currentClassKey = myClassKey() or "<none>",
			currentClassId = myClassId() or "<none>",
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
				local nextState = table.clone(variantByClassKey())
				nextState[classKey] = nextIndex
				variantByClassKey(nextState)
				return
			end
		end
	end

	local selectedClassEntry = derive(function()
		local resolvedViewModel = viewModel()
		if not resolvedViewModel then
			return nil
		end

		local currentClassKey = myClassKey()
		if not currentClassKey then
			return nil
		end

		for _, classEntry in ipairs(resolvedViewModel.classes) do
			if classEntry.classKey == currentClassKey then
				return classEntry
			end
		end

		return nil
	end)

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
		create "TextButton" {
			Name = "ModalToggler",
			Modal = function() return isOpen() end,
		},
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
								return if myVariantConfig() then (myVariantConfig().Description or "Lorem ipsum on the beat yo!\n\n\n(no description)") else "<no class selected...>"
							end,
						}
					}
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

						VariantSelector({
							title = "VARIANT",
							titleHeight = 0.5,
							size = UDim2.fromScale(1, 0.25),
							ValueText = function()
								local variantConfig = myVariantConfig()
								if not variantConfig then
									return "<no variant selected...>"
								end
								print(variantConfig)
								return variantConfig.Name or "<no variant name...>"
							end,
							LeftActivated = function()
								cycleVariant(myClassKey(), -1)
							end,
							RightActivated = function()
								cycleVariant(myClassKey(), 1)
							end,
						})
					},
					


				},
			},
			
		}
	}
	
end