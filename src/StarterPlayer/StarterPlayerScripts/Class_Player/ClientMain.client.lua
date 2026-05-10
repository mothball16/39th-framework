local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Maid = require(Access.Packages.maid)
local Vide = require(Access.Packages.Vide)
local VideCharm = require(Access.Packages["vide-charm"])
local useAtom = VideCharm.useAtom
local create = Vide.create
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local State = require(Access.Framework.Core:WaitForChild("State"))

local ClientMirror = require(script.Parent.ClientMirror)
local SelectorUI = require(script.Parent.UI.Roots.SelectorUI)

local maid = Maid.new()
local state = State.new()
local mirror = ClientMirror.new({
	factionConfigs = state.factionConfigs,
	playerFactionIds = state.playerFactionIds,
	playerClassKeys = state.playerClassKeys,
	playerClassIds = state.playerClassIds,
	classCountsByFaction = state.classCountsByFaction,
}, Events)
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local unmountSelector = Vide.mount(function()
	return create "ScreenGui" {
		Name = "SelectorUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		SelectorUI({
			factionConfigs = useAtom(state.factionConfigs),
			playerFactionIds = useAtom(state.playerFactionIds),
			playerClassKeys = useAtom(state.playerClassKeys),
			playerClassIds = useAtom(state.playerClassIds),
			classCountsByFaction = useAtom(state.classCountsByFaction),
			requestClass = function(classKey: string, classId: string)
				Events.RequestClass:FireServer({
					classKey = classKey,
					classId = classId,
				})
			end,
		}),
	}
end, playerGui)

maid:GiveTask(function()
	if type(unmountSelector) == "function" then
		unmountSelector()
	end
end)
maid:GiveTask(mirror)

script.Destroying:Connect(function()
	maid:DoCleaning()
end)