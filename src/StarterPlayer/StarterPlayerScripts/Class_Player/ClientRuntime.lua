local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Maid = require(Access.Packages.maid)
local Vide = require(Access.Packages.Vide)

local create = Vide.create
local Events = require(Access.Framework.Core:WaitForChild("Events"))
local State = require(Access.Framework.Core:WaitForChild("State"))

local ClientMirror = require(script.Parent.ClientMirror)
local SelectorUI = require(script.Parent.UI.Roots.SelectorUI)

local ClientRuntime = {}
ClientRuntime.__index = ClientRuntime

type self = {
	state: State.State,
	mirror: any,
	maid: Maid.Maid,
	isOpen: Vide.Source<boolean>,
}
export type ClientRuntime = typeof(setmetatable({} :: self, ClientRuntime))

function ClientRuntime.new()
	local state = State.new()
	local maid = Maid.new()
	local mirror = ClientMirror.new(state, Events)
	local isOpen = Vide.source(false)

	local self = setmetatable({
		state = state,
		mirror = mirror,
		maid = maid,
		isOpen = isOpen,
	} :: self, ClientRuntime)

	return self
end

-- wires up UI and lifecycle. don't call for tests

function ClientRuntime.Start(self: ClientRuntime)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local unmountSelector = Vide.mount(function()
		return create "ScreenGui" {
			Name = "SelectorUI",
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

			SelectorUI({
				isOpen = self.isOpen,
				ManualButton = false,
				playerKey = tostring(Players.LocalPlayer.UserId),
				state = self.state:AsVideSources(),
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

	self.maid:GiveTask(unmountSelector)
	self.maid:GiveTask(self.mirror)
end

function ClientRuntime.Destroy(self: ClientRuntime)
	self.maid:DoCleaning()
end

return ClientRuntime
