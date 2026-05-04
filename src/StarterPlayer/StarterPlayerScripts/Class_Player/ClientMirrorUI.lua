local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Charm"))
local ClientUIConfig = require(script.Parent.ClientUIConfig)
local Theme = require(script.Parent.UI.Theme)
local ClassSelectorLayout = require(script.Parent.UI.ClassSelectorLayout)
local RoleRow = require(script.Parent.UI.RoleRow)

local ClientMirrorUI = {}
ClientMirrorUI.__index = ClientMirrorUI

type ClassEntry = {
	classKey: string,
	classId: string?,
	count: number,
	limit: number,
	isCurrent: boolean,
	isFull: boolean,
	variants: {string},
	selectedVariantIndex: number,
}

type ViewModel = {
	factionId: string,
	currentClassKey: string,
	currentClassId: string,
	classes: {ClassEntry},
}

type Callbacks = {
	onTogglePressed: ((ui: any) -> ())?,
	onMoveUpPressed: ((ui: any) -> ())?,
	onMoveDownPressed: ((ui: any) -> ())?,
	onMoveLeftPressed: ((ui: any) -> ())?,
	onMoveRightPressed: ((ui: any) -> ())?,
	onConfirmPressed: ((ui: any) -> ())?,
	onRequestClass: ((ui: any, classKey: string, classId: string) -> ())?,
}

type Options = {
	callbacks: Callbacks?,
}

local function wrapIndex(current: number, offset: number, count: number): number
	if count <= 0 then
		return 1
	end
	return ((current - 1 + offset) % count) + 1
end

local function buildViewModel(
	factionConfigs: {[string]: any},
	playerFactionIds: {[string]: string},
	playerClassKeys: {[string]: string},
	playerClassIds: {[string]: string},
	classCountsByFaction: {[string]: {[string]: number}},
	userId: number,
	selectedVariantByClassKey: {[string]: number}
): ViewModel?
	local playerKey = tostring(userId)
	local factionId = playerFactionIds[playerKey]
	local currentClassKey = playerClassKeys[playerKey]
	local currentClassId = playerClassIds[playerKey]
	if not factionId or not currentClassKey or not currentClassId then
		return nil
	end

	local factionConfig = factionConfigs[factionId]
	if not factionConfig then
		return nil
	end

	local classCounts = classCountsByFaction[factionId] or {}

	local classes = {}
	for classKey, classConfig in pairs(factionConfig.Classes) do
		local variants = {}
		for _, variant in ipairs(classConfig.ClassIDs or {}) do
			table.insert(variants, variant.Id)
		end
		local selectedVariantIndex = selectedVariantByClassKey[classKey]

		if not selectedVariantIndex and classKey == currentClassKey then
			for variantIndex, variantClassId in ipairs(variants) do
				if variantClassId == currentClassId then
					selectedVariantIndex = variantIndex
					break
				end
			end
		end

		selectedVariantIndex = selectedVariantIndex or 1
		if selectedVariantIndex < 1 then
			selectedVariantIndex = 1
		elseif selectedVariantIndex > #variants and #variants > 0 then
			selectedVariantIndex = #variants
		end

		local classId = variants[selectedVariantIndex]
		local limit = classConfig.Limit
		local count = classCounts[classKey] or 0
		table.insert(classes, {
			classKey = classKey,
			classId = classId,
			count = count,
			limit = limit,
			isCurrent = currentClassKey == classKey and currentClassId == classId,
			isFull = limit > 0 and count >= limit,
			variants = variants,
			selectedVariantIndex = selectedVariantIndex,
		})
	end

	table.sort(classes, function(a, b)
		return a.classKey < b.classKey
	end)

	return {
		factionId = factionId,
		currentClassKey = currentClassKey or "None",
		currentClassId = currentClassId or "None",
		classes = classes,
	}
end

function ClientMirrorUI.new(atoms, options: Options?)
	local self = setmetatable({}, ClientMirrorUI)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	self.atoms = atoms
	self.localUserId = Players.LocalPlayer.UserId
	self.callbacks = if options and options.callbacks then options.callbacks else {}
	self.visible = false
	self.selectedIndex = 1
	self.selectedVariantByClassKey = {}
	self.statusText = "Select a role and press request class."
	self.lastViewModel = nil
	self.connections = {}
	self.cleanups = {}
	self.roleButtons = {}
	self.confirmEnabled = false

	self.refs = ClassSelectorLayout.build(playerGui, ClientUIConfig.ToggleKeyCode.Name, self.statusText)
	self.gui = self.refs.Gui
	self.roleList = self.refs.RoleList
	self.roleListLayout = self.refs.RoleListLayout
	self.factionText = self.refs.FactionText
	self.currentText = self.refs.CurrentText
	self.selectedRoleText = self.refs.SelectedRoleText
	self.selectedVariantText = self.refs.SelectedVariantText
	self.availabilityText = self.refs.AvailabilityText
	self.variantValueText = self.refs.VariantValueText
	self.variantCounterText = self.refs.VariantCounterText
	self.prevVariantButton = self.refs.PrevVariantButton
	self.nextVariantButton = self.refs.NextVariantButton
	self.requestButton = self.refs.RequestButton
	self.closeButton = self.refs.CloseButton
	self.statusLabel = self.refs.StatusLabel

	self:_bindUI()
	self:SetVisible(false)
	self:_refresh(true)
	self:_bindAtomSubscriptions()

	return self
end

function ClientMirrorUI:_addCleanup(cleanup: any)
	table.insert(self.cleanups, cleanup)
end

function ClientMirrorUI:_runCleanup(cleanup: any)
	if typeof(cleanup) == "RBXScriptConnection" then
		cleanup:Disconnect()
	elseif type(cleanup) == "function" then
		cleanup()
	end
end

function ClientMirrorUI:_onAtomChanged()
	if self.visible then
		self:_refresh(false)
	end
end

function ClientMirrorUI:_bindAtomSubscriptions()
	self:_addCleanup(Charm.subscribe(self.atoms.factionConfigs, function()
		self:_onAtomChanged()
	end))
	self:_addCleanup(Charm.subscribe(self.atoms.playerFactionIds, function()
		self:_onAtomChanged()
	end))
	self:_addCleanup(Charm.subscribe(self.atoms.playerClassKeys, function()
		self:_onAtomChanged()
	end))
	self:_addCleanup(Charm.subscribe(self.atoms.playerClassIds, function()
		self:_onAtomChanged()
	end))
	self:_addCleanup(Charm.subscribe(self.atoms.classCountsByFaction, function()
		self:_onAtomChanged()
	end))
end

function ClientMirrorUI:_bindUI()
	table.insert(self.connections, self.roleListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local contentHeight = self.roleListLayout.AbsoluteContentSize.Y
		self.roleList.CanvasSize = UDim2.fromOffset(0, contentHeight + 16)
	end))
	table.insert(self.connections, self.prevVariantButton.Activated:Connect(function()
		self:OnMoveLeftPressed()
	end))
	table.insert(self.connections, self.nextVariantButton.Activated:Connect(function()
		self:OnMoveRightPressed()
	end))
	table.insert(self.connections, self.requestButton.Activated:Connect(function()
		self:OnConfirmPressed()
	end))
	table.insert(self.connections, self.closeButton.Activated:Connect(function()
		self:OnTogglePressed()
	end))
end

function ClientMirrorUI:_createRoleButton(index: number): TextButton
	local button = RoleRow.create(self.roleList, index, function(roleIndex)
		self.selectedIndex = roleIndex
		local selectedClass = if self.lastViewModel then self.lastViewModel.classes[self.selectedIndex] else nil
		if selectedClass then
			local selectedClassId = selectedClass.classId or "None"
			self.statusText = `Selected role: {selectedClass.classKey} / {selectedClassId}`
		end
		self:_refresh(true)
	end)
	table.insert(self.roleButtons, button)
	return button
end

function ClientMirrorUI:_setActionButtonEnabled(button: TextButton, enabled: boolean, enabledColor: Color3)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then enabledColor else Theme.Colors.DisabledActionBackground
	button.TextTransparency = if enabled then 0 else 0.2
end

function ClientMirrorUI:_setVariantButtonsEnabled(enabled: boolean)
	self:_setActionButtonEnabled(self.prevVariantButton, enabled, Theme.Colors.RowBackground)
	self:_setActionButtonEnabled(self.nextVariantButton, enabled, Theme.Colors.RowBackground)
end

function ClientMirrorUI:_setRequestState(enabled: boolean, text: string)
	self.confirmEnabled = enabled
	self:_setActionButtonEnabled(self.requestButton, enabled, Theme.Colors.PrimaryActionBackground)
	self.requestButton.Text = text
end

function ClientMirrorUI:_hideRoleButtons()
	for _, button in ipairs(self.roleButtons) do
		button.Visible = false
		button:SetAttribute("RoleIndex", nil)
	end
end

function ClientMirrorUI:_setStatusAndRefresh(statusText: string)
	self.statusText = statusText
	self:_refresh(true)
end

function ClientMirrorUI:_runSimpleCallback(callback: ((ui: any) -> ())?, fallback: () -> ())
	if callback then
		callback(self)
		return
	end
	fallback()
end

function ClientMirrorUI:_clampSelection(classCount: number)
	if classCount <= 0 then
		self.selectedIndex = 1
		return
	end
	self.selectedIndex = math.clamp(self.selectedIndex, 1, classCount)
end

function ClientMirrorUI:_refreshRoleButtons(viewModel: ViewModel)
	for index, classEntry in ipairs(viewModel.classes) do
		local button = self.roleButtons[index] or self:_createRoleButton(index)
		button.Visible = true
		button.LayoutOrder = index
		button:SetAttribute("RoleIndex", index)

		RoleRow.update(button, classEntry, index == self.selectedIndex)
	end

	for index = #viewModel.classes + 1, #self.roleButtons do
		self.roleButtons[index].Visible = false
		self.roleButtons[index]:SetAttribute("RoleIndex", nil)
	end
end

function ClientMirrorUI:_refreshSelectionDetails(viewModel: ViewModel)
	local selectedClass = viewModel.classes[self.selectedIndex]
	self.factionText.Text = `Faction: {viewModel.factionId}`
	self.currentText.Text = `Current: {viewModel.currentClassKey} / {viewModel.currentClassId}`

	if not selectedClass then
		self.selectedRoleText.Text = "No role selected"
		self.selectedVariantText.Text = "Variant: -"
		self.availabilityText.TextColor3 = Theme.Colors.TextSecondary
		self.availabilityText.Text = "Availability: No classes available"
		self.variantValueText.Text = "No variants"
		self.variantCounterText.Text = "0 / 0"
		self:_setVariantButtonsEnabled(false)
		self:_setRequestState(false, "Request Class")
		return
	end

	local variantCount = #selectedClass.variants
	local selectedVariant = selectedClass.classId or "None"
	local availabilityLine: string
	local availabilityColor: Color3

	if selectedClass.isCurrent then
		availabilityLine = "Availability: Equipped"
		availabilityColor = Theme.Colors.Success
	elseif selectedClass.isFull then
		availabilityLine = "Availability: Full"
		availabilityColor = Theme.Colors.Danger
	else
		availabilityLine = "Availability: Open"
		availabilityColor = Theme.Colors.Success
	end

	local slotText = if selectedClass.limit > 0 then `{selectedClass.count}/{selectedClass.limit}` else `{selectedClass.count}/-`
	self.selectedRoleText.Text = selectedClass.classKey
	self.selectedVariantText.Text = `Variant: {selectedVariant}`
	self.availabilityText.Text = `{availabilityLine}  |  Slots {slotText}`
	self.availabilityText.TextColor3 = availabilityColor
	self.variantValueText.Text = selectedVariant
	self.variantCounterText.Text = if variantCount > 0
		then `{selectedClass.selectedVariantIndex} / {variantCount}`
		else "0 / 0"

	local canCycleVariants = variantCount > 1
	self:_setVariantButtonsEnabled(canCycleVariants)

	local canRequest = selectedClass.classId ~= nil and (not selectedClass.isFull or selectedClass.isCurrent)
	local requestText = if selectedClass.isCurrent
		then "Already Equipped"
		elseif selectedClass.isFull then "Role Full"
		else "Request Class"
	self:_setRequestState(canRequest, requestText)
end

function ClientMirrorUI:_refresh(forceRender: boolean)
	local factionConfigs = self.atoms.factionConfigs()
	local playerFactionIds = self.atoms.playerFactionIds()
	local playerClassKeys = self.atoms.playerClassKeys()
	local playerClassIds = self.atoms.playerClassIds()
	local classCountsByFaction = self.atoms.classCountsByFaction()
	local viewModel = buildViewModel(
		factionConfigs,
		playerFactionIds,
		playerClassKeys,
		playerClassIds,
		classCountsByFaction,
		self.localUserId,
		self.selectedVariantByClassKey
	)
	self.lastViewModel = viewModel
	self.statusLabel.Text = self.statusText

	if not viewModel then
		self.factionText.Text = "Faction: Unassigned"
		self.currentText.Text = "Current: None"
		self.selectedRoleText.Text = "Awaiting faction assignment"
		self.selectedVariantText.Text = "Variant: -"
		self.availabilityText.TextColor3 = Theme.Colors.TextSecondary
		self.availabilityText.Text = "Availability: Waiting for server state"
		self.variantValueText.Text = "No variants"
		self.variantCounterText.Text = "0 / 0"
		self:_setVariantButtonsEnabled(false)
		self:_setRequestState(false, "Request Class")
		self:_hideRoleButtons()
		return
	end

	self:_clampSelection(#viewModel.classes)
	self:_refreshRoleButtons(viewModel)
	self:_refreshSelectionDetails(viewModel)

	if forceRender then
		self.statusLabel.Text = self.statusText
	end
end

function ClientMirrorUI:Toggle()
	self:SetVisible(not self.visible)
end

function ClientMirrorUI:OnTogglePressed()
	local callback = self.callbacks.onTogglePressed
	if callback then
		callback(self)
		return
	end
	self:Toggle()
end

function ClientMirrorUI:SetVisible(isVisible: boolean)
	self.visible = isVisible
	if self.gui then
		self.gui.Enabled = isVisible
	end
	if isVisible then
		self:_refresh(true)
	end
end

function ClientMirrorUI:IsVisible(): boolean
	return self.visible
end

function ClientMirrorUI:MoveSelection(offset: number)
	local viewModel = self.lastViewModel
	if not viewModel or #viewModel.classes == 0 then
		return
	end

	local nextIndex = wrapIndex(self.selectedIndex, offset, #viewModel.classes)
	self.selectedIndex = nextIndex

	local selectedClass = viewModel.classes[nextIndex]
	if selectedClass then
		local selectedClassId = selectedClass.classId or "None"
		self.statusText = `Selected role: {selectedClass.classKey} / {selectedClassId}`
	end
	self:_refresh(true)
end

function ClientMirrorUI:MoveVariant(offset: number)
	local viewModel = self.lastViewModel
	if not viewModel or #viewModel.classes == 0 then
		return
	end
	self:_clampSelection(#viewModel.classes)

	local selectedClass = viewModel.classes[self.selectedIndex]
	if not selectedClass then
		return
	end
	local variantCount = #selectedClass.variants
	if variantCount == 0 then
		return
	end

	local nextVariantIndex = wrapIndex(selectedClass.selectedVariantIndex, offset, variantCount)

	self.selectedVariantByClassKey[selectedClass.classKey] = nextVariantIndex
	local nextClassId = selectedClass.variants[nextVariantIndex] or "None"
	self.statusText = `Variant: {selectedClass.classKey} / {nextClassId}`
	self:_refresh(true)
end

function ClientMirrorUI:OnMoveUpPressed()
	self:_runSimpleCallback(self.callbacks.onMoveUpPressed, function() self:MoveSelection(-1) end)
end

function ClientMirrorUI:OnMoveDownPressed()
	self:_runSimpleCallback(self.callbacks.onMoveDownPressed, function() self:MoveSelection(1) end)
end

function ClientMirrorUI:OnMoveLeftPressed()
	self:_runSimpleCallback(self.callbacks.onMoveLeftPressed, function() self:MoveVariant(-1) end)
end

function ClientMirrorUI:OnMoveRightPressed()
	self:_runSimpleCallback(self.callbacks.onMoveRightPressed, function() self:MoveVariant(1) end)
end

function ClientMirrorUI:RequestSelectedClass()
	local viewModel = self.lastViewModel
	if not viewModel or #viewModel.classes == 0 then
		self:_setStatusAndRefresh("Cannot request class yet.")
		return
	end

	self:_clampSelection(#viewModel.classes)
	local selectedClass = viewModel.classes[self.selectedIndex]
	if not selectedClass then
		self:_setStatusAndRefresh("No class selected.")
		return
	end
	if not selectedClass.classId then
		self:_setStatusAndRefresh("Selected role has no variants.")
		return
	end
	if selectedClass.isFull and not selectedClass.isCurrent then
		self:_setStatusAndRefresh(`Role {selectedClass.classKey} is currently full.`)
		return
	end

	local callback = self.callbacks.onRequestClass
	if callback then
		callback(self, selectedClass.classKey, selectedClass.classId)
	else
		warn("ClientMirrorUI missing onRequestClass callback")
	end
	self.statusText = `Requested: {selectedClass.classKey} / {selectedClass.classId}`
	self:_refresh(true)
end

function ClientMirrorUI:OnConfirmPressed()
	local callback = self.callbacks.onConfirmPressed
	if callback then
		callback(self)
		return
	end
	if not self.confirmEnabled then
		return
	end
	self:RequestSelectedClass()
end

function ClientMirrorUI:Destroy()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	table.clear(self.connections)
	for _, cleanup in ipairs(self.cleanups) do
		self:_runCleanup(cleanup)
	end
	table.clear(self.cleanups)

	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

return ClientMirrorUI
