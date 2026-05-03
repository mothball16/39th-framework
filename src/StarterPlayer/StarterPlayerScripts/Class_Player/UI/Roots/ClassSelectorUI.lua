local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)
local create = Vide.create
local source = Vide.source
local derive = Vide.derive
local indexes = Vide.indexes

local UIComponents = script.Parent.Parent.Components
local ClassCard = require(UIComponents.ClassCard)

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

	local viewModel = derive(function()
		local localFactionId = props.playerFactionIds()[playerKey]
		if not localFactionId then
			return nil
		end

		local localFactionConfig = props.factionConfigs()[localFactionId]
		if not localFactionConfig then
			return nil
		end

		local localCurrentClassKey = props.playerClassKeys()[playerKey]
		local localCurrentClassId = props.playerClassIds()[playerKey]
		local localClassCounts = props.classCountsByFaction()[localFactionId] or {}

		-- build class entires
		local classes = {}
		for classKey, classConfig in pairs(localFactionConfig.Classes) do
			local variants = classConfig.ClassIDs or {}
			local selectedIndex = selectedVariantByClassKey()[classKey]
			if not selectedIndex then
				selectedIndex = 1
				if classKey == localCurrentClassKey then
					for variantIndex, variantClassId in ipairs(variants) do
						if variantClassId == localCurrentClassId then
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
			local count = localClassCounts[classKey] or 0
			local limit = classConfig.Limit or 0
			table.insert(classes, {
				classKey = classKey,
				classId = selectedClassId or "None",
				selectedVariantIndex = selectedIndex,
				count = count,
				limit = limit,
				isFull = limit > 0 and count >= limit,
				isCurrentKey = localCurrentClassKey == classKey,
				isCurrentId = localCurrentClassId == selectedClassId,
			})
		end

		table.sort(classes, function(a, b)
			return a.classKey < b.classKey
		end)

		return {
			factionId = localFactionId,
			currentClassKey = localCurrentClassKey or "<none>",
			currentClassId = localCurrentClassId or "<none>",
			classes = classes,
		}
	end)

	local function cycleVariant(classKey: string, offset: number)
		for _, classEntry in ipairs(viewModel().classes) do
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

	local classEntries = derive(function()
		return if viewModel() then viewModel().classes else {}
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
					if not item() or (item().isFull and not item().isCurrent) then
						return
					end
					props.requestClass(item().classKey, item().classId)
				end,
			})
	end)

	---------------------- [template] ----------------------

	return create "Frame" {
		Name = "ClassSelectorUI",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.55, 0, 0.8, 0),
		BackgroundColor3 = Color3.fromRGB(12, 12, 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		create "UICorner" {
			CornerRadius = UDim.new(0, 8),
		},
		create "UIPadding" {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
		},
		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 8),
		},

		create "TextLabel" {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.RobotoCondensed,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = function()
				local localViewModel = viewModel()
				if not localViewModel then
					return "CLASS SELECTOR - Waiting for faction"
				end
				return `CLASS SELECTOR - {localViewModel.factionId}`
			end,
		},

		create "TextLabel" {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.RobotoMono,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = function()
				local localViewModel = viewModel()
				if not localViewModel then
					return "Current: None"
				end
				return `Current: {localViewModel.currentClassKey} / {localViewModel.currentClassId}`
			end,
		},

		create "TextLabel" {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.RobotoMono,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "Select a role, cycle variant, then press SELECT.",
		},

		create "ScrollingFrame" {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 1, -76),
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
	}
end