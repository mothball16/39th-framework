local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Maid = require(Access.Packages.maid)
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local State = require(Access.Framework.Core:WaitForChild("State"))

local ClientMirror = require(script.Parent.ClientMirror)
local ClientMirrorUI = require(script.Parent.ClientMirrorUI)
local ClientUIConfig = require(script.Parent.ClientUIConfig)

local maid = Maid.new()
local state = State.new()
local mirror = ClientMirror.new({
	Factions = state.Factions,
}, Events)
local mirrorUI = ClientMirrorUI.new(mirror.atoms)

maid:GiveTask(mirror)
maid:GiveTask(mirrorUI)
maid:GiveTask(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if input.KeyCode == ClientUIConfig.ToggleKeyCode then
		mirrorUI:Toggle()
	end
end))

script.Destroying:Connect(function()
	maid:DoCleaning()
end)