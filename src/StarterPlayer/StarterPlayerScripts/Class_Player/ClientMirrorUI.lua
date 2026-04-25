local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Types = require(Access.Framework.Core:WaitForChild("Types"))
local Vide = require(Access.Packages.Vide)
local VideCharm = require(Access.Packages["vide-charm"])
local ClientUIConfig = require(script.Parent.ClientUIConfig)

local create = Vide.create
local mount = Vide.mount
local source = Vide.source
local useAtom = VideCharm.useAtom

local TITLE_HEIGHT = 26
local PADDING = 8

local ClientMirrorUI = {}
ClientMirrorUI.__index = ClientMirrorUI

local function keySort(a, b)
	return tostring(a) < tostring(b)
end

local function serializeValue(value: any, depth: number, maxDepth: number): string
	local valueType = typeof(value)

	if valueType == "string" then
		return value
	elseif valueType == "number" or valueType == "boolean" then
		return tostring(value)
	elseif valueType == "nil" then
		return "nil"
	elseif valueType == "Instance" then
		local instanceValue = value :: Instance
		return `{instanceValue.ClassName}({instanceValue:GetFullName()})`
	elseif valueType ~= "table" then
		return tostring(value)
	end

	if depth >= maxDepth then
		return "{...}"
	end

	local tableValue = value :: {[any]: any}
	local keys = {}
	for key in tableValue do
		table.insert(keys, key)
	end
	table.sort(keys, keySort)

	if #keys == 0 then
		return "{}"
	end

	local parts = {}
	local limit = math.min(#keys, 8)
	for index = 1, limit do
		local key = keys[index]
		parts[index] = `{tostring(key)}={serializeValue(tableValue[key], depth + 1, maxDepth)}`
	end

	if #keys > limit then
		table.insert(parts, "...")
	end

	return `{` .. table.concat(parts, ", ") .. `}`
end

local function serializeState(state: any): string
	if typeof(state) ~= "table" then
		return serializeValue(state, 0, ClientUIConfig.MaxDepth)
	end

	local stateTable = state :: {[any]: any}
	local keys = {}
	for key in stateTable do
		table.insert(keys, key)
	end
	table.sort(keys, keySort)

	if #keys == 0 then
		return "(empty)"
	end

	local lines = {}
	local limit = math.min(#keys, ClientUIConfig.MaxRows)

	for index = 1, limit do
		local key = keys[index]
		lines[index] = `{tostring(key)}: {serializeValue(stateTable[key], 0, ClientUIConfig.MaxDepth)}`
	end

	if #keys > limit then
		table.insert(lines, `... ({#keys - limit} more keys)`)
	end

	return table.concat(lines, "\n")
end

function ClientMirrorUI.new(atoms: Types.Atoms)
	local self = setmetatable({}, ClientMirrorUI)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	self.visible = source(false)
	self.unmount = mount(function()
		local mirroredState = useAtom(atoms.State)

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
					Text = `{ClientUIConfig.Title} [{ClientUIConfig.ToggleKeyCode.Name}]`,
				}),
				create("TextLabel")({
					Name = "StateText",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, PADDING, 0, PADDING + TITLE_HEIGHT + 4),
					Size = UDim2.new(1, -PADDING * 2, 1, -(PADDING * 2 + TITLE_HEIGHT + 4)),
					Font = Enum.Font.Code,
					TextSize = 14,
					TextColor3 = Color3.fromRGB(226, 232, 240),
					TextWrapped = false,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Text = function()
						return serializeState(mirroredState())
					end,
				}),
			}),
		})
	end, playerGui)

	return self
end

function ClientMirrorUI:Toggle()
	self.visible(not self.visible())
end

function ClientMirrorUI:SetVisible(isVisible: boolean)
	self.visible(isVisible)
end

function ClientMirrorUI:Destroy()
	if self.unmount then
		self.unmount()
		self.unmount = nil
	end
end

return ClientMirrorUI
