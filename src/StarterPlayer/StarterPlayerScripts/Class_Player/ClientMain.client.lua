local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Maid = require(Access.Packages.maid)
local Vide = require(Access.Packages.Vide)

local create = Vide.create
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local State = require(Access.Framework.Core:WaitForChild("State"))

local ClientMirror = require(script.Parent.ClientMirror)
local SelectorUI = require(script.Parent.UI.Roots.SelectorUI)

local maid = Maid.new()
local state = State.new()
local mirror = ClientMirror.new(state, Events)

local unmountSelector = Vide.mount(function()
	return create "ScreenGui" {
		Name = "SelectorUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		SelectorUI({
			playerKey = tostring(Players.LocalPlayer.UserId),
			state = state:AsVideSources(),
			requestClass = function(classKey: string, classId: string)
				Events.RequestClass:FireServer({
					classKey = classKey,
					classId = classId,
				})
			end,
			requestClassApply = function(enable: boolean)
				Events.RequestClassApply:FireServer({
					enable = enable,
				})
			end,
		}),
	}
end, playerGui)

maid:GiveTask(unmountSelector)
maid:GiveTask(mirror)

script.Destroying:Connect(function()
	maid:DoCleaning()
end)