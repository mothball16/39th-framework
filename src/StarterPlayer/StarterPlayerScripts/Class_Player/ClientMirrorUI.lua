local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Vide = require(Access.Packages.Vide)
local VideCharm = require(Access.Packages["vide-charm"])
local ClientUIConfig = require(script.Parent.ClientUIConfig)

local create = Vide.create
local mount = Vide.mount
local source = Vide.source
local useAtom = VideCharm.useAtom

local TITLE_HEIGHT = 24
local PADDING = 8

local ClientMirrorUI = {}
ClientMirrorUI.__index = ClientMirrorUI

type ClassEntry = {
	classId: string,
	count: number,
	limit: number,
	isCurrent: boolean,
	isFull: boolean,
}

type ViewModel = {
	factionId: string,
	currentClassId: string,
	classes: {ClassEntry},
}

local function buildViewModel(
	factionConfigs: {[string]: any},
	membershipByUserId: {[string]: any},
	classCountsByFaction: {[string]: {[string]: number}},
	userId: number
): ViewModel?
	local assignment = membershipByUserId[tostring(userId)]
	if not assignment then
		return nil
	end
	local factionId = assignment.FactionId
	local currentClassId = assignment.ClassId

	local factionConfig = factionConfigs[factionId]
	if not factionConfig then
		return nil
	end

	local classCounts = classCountsByFaction[factionId] or {}
	local classes = {}
	for _, classConfig in pairs(factionConfig.Classes) do
		local classId = classConfig.ClassID
		local limit = classConfig.Limit
		local count = classCounts[classId] or 0
		table.insert(classes, {
			classId = classId,
			count = count,
			limit = limit,
			isCurrent = currentClassId == classId,
			isFull = limit > 0 and count >= limit,
		})
	end
	table.sort(classes, function(a, b)
		return a.classId < b.classId
	end)

	return {
		factionId = factionId,
		currentClassId = currentClassId or "None",
		classes = classes,
	}
end

local function formatClassList(viewModel: ViewModel, selectedIndex: number): string
	if #viewModel.classes == 0 then
		return "No classes available."
	end

	local lines = table.create(#viewModel.classes)
	for index, classEntry in ipairs(viewModel.classes) do
		local selectedPrefix = if index == selectedIndex then ">" else " "
		local tags = {}
		if classEntry.isCurrent then
			table.insert(tags, "current")
		end
		if classEntry.isFull then
			table.insert(tags, "full")
		end
		local tagSuffix = if #tags > 0 then ` [{table.concat(tags, ", ")}]` else ""
		lines[index] = `{selectedPrefix} [{index}] {classEntry.classId} ({classEntry.count}/{classEntry.limit}){tagSuffix}`
	end

	return table.concat(lines, "\n")
end

function ClientMirrorUI.new(atoms, events)
	local self = setmetatable({}, ClientMirrorUI)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local localUserId = Players.LocalPlayer.UserId

	self.events = events
	self.visible = source(false)
	self.selectedIndex = source(1)
	self.statusText = source("Select a class and press Enter to request.")
	self.lastViewModel = nil
	self.unmount = mount(function()
		local factionConfigs = useAtom(atoms.FactionConfigs)
		local membershipByUserId = useAtom(atoms.MembershipByUserId)
		local classCountsByFaction = useAtom(atoms.ClassCountsByFaction)

		return create("ScreenGui")({
			Name = "ClassMirrorUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			Enabled = function()
				return self.visible()
			end,
			create("Frame")({
				Name = "Panel",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 16, 0.5, 0),
				Size = UDim2.new(0, 450, 0, 360),
				BackgroundColor3 = Color3.fromRGB(22, 24, 30),
				BorderSizePixel = 0,
				create("UICorner")({
					CornerRadius = UDim.new(0, 8),
				}),
				create("TextLabel")({
					Name = "Title",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, PADDING, 0, PADDING),
					Size = UDim2.new(1, -PADDING * 2, 0, TITLE_HEIGHT),
					Font = Enum.Font.GothamBold,
					TextSize = 16,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = `Class Selection [{ClientUIConfig.ToggleKeyCode.Name}]`,
				}),
				create("TextLabel")({
					Name = "FactionText",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, PADDING, 0, PADDING + TITLE_HEIGHT + 2),
					Size = UDim2.new(1, -PADDING * 2, 0, 20),
					Font = Enum.Font.Gotham,
					TextSize = 14,
					TextColor3 = Color3.fromRGB(226, 232, 240),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = function()
						local viewModel = buildViewModel(
							factionConfigs(),
							membershipByUserId(),
							classCountsByFaction(),
							localUserId
						)
						self.lastViewModel = viewModel
						if not viewModel then
							return "Faction: Unassigned"
						end
						return `Faction: {viewModel.factionId}`
					end,
				}),
				create("TextLabel")({
					Name = "CurrentClassText",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, PADDING, 0, PADDING + TITLE_HEIGHT + 22),
					Size = UDim2.new(1, -PADDING * 2, 0, 20),
					Font = Enum.Font.Gotham,
					TextSize = 14,
					TextColor3 = Color3.fromRGB(226, 232, 240),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = function()
						local viewModel = buildViewModel(
							factionConfigs(),
							membershipByUserId(),
							classCountsByFaction(),
							localUserId
						)
						self.lastViewModel = viewModel
						if not viewModel then
							return "Current Class: None"
						end
						return `Current Class: {viewModel.currentClassId}`
					end,
				}),
				create("TextLabel")({
					Name = "HelpText",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, PADDING, 0, PADDING + TITLE_HEIGHT + 42),
					Size = UDim2.new(1, -PADDING * 2, 0, 18),
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(148, 163, 184),
					TextXAlignment = Enum.TextXAlignment.Left,
					Text = "Up/Down: Select  Enter: Request Class",
				}),
				create("TextLabel")({
					Name = "ClassList",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, PADDING, 0, PADDING + TITLE_HEIGHT + 64),
					Size = UDim2.new(1, -PADDING * 2, 1, -(PADDING * 2 + TITLE_HEIGHT + 92)),
					Font = Enum.Font.Code,
					TextSize = 14,
					TextColor3 = Color3.fromRGB(226, 232, 240),
					TextWrapped = false,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = function()
						local viewModel = buildViewModel(
							factionConfigs(),
							membershipByUserId(),
							classCountsByFaction(),
							localUserId
						)
						self.lastViewModel = viewModel
						if not viewModel then
							return "No faction assignment yet."
						end
						self:_clampSelection(#viewModel.classes)
						return formatClassList(viewModel, self.selectedIndex())
					end,
				}),
				create("TextLabel")({
					Name = "StatusText",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, PADDING, 1, -(PADDING + 18)),
					Size = UDim2.new(1, -PADDING * 2, 0, 18),
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextColor3 = Color3.fromRGB(148, 163, 184),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					Text = function()
						return self.statusText()
					end,
				}),
			}),
		})
	end, playerGui)

	return self
end

function ClientMirrorUI:_clampSelection(classCount: number)
	if classCount <= 0 then
		self.selectedIndex(1)
		return
	end

	local index = self.selectedIndex()
	if index < 1 then
		self.selectedIndex(1)
	elseif index > classCount then
		self.selectedIndex(classCount)
	end
end

function ClientMirrorUI:Toggle()
	self.visible(not self.visible())
end

function ClientMirrorUI:SetVisible(isVisible: boolean)
	self.visible(isVisible)
end

function ClientMirrorUI:IsVisible(): boolean
	return self.visible()
end

function ClientMirrorUI:MoveSelection(offset: number)
	local viewModel = self.lastViewModel
	if not viewModel or #viewModel.classes == 0 then
		return
	end

	local nextIndex = self.selectedIndex() + offset
	if nextIndex < 1 then
		nextIndex = #viewModel.classes
	elseif nextIndex > #viewModel.classes then
		nextIndex = 1
	end
	self.selectedIndex(nextIndex)
end

function ClientMirrorUI:RequestSelectedClass()
	local viewModel = self.lastViewModel
	if not viewModel or #viewModel.classes == 0 then
		self.statusText("Cannot request class yet.")
		return
	end
	self:_clampSelection(#viewModel.classes)

	local selectedClass = viewModel.classes[self.selectedIndex()]
	if not selectedClass then
		self.statusText("No class selected.")
		return
	end

	self.events.RequestClass:FireServer(selectedClass.classId)
	self.statusText(`Requested class: {selectedClass.classId}`)
end

function ClientMirrorUI:Destroy()
	if self.unmount then
		self.unmount()
		self.unmount = nil
	end
end

return ClientMirrorUI
