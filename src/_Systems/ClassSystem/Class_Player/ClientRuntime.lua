local Players = game:GetService("Players")

local Maid = require("@game/ReplicatedStorage/Packages/maid")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local VideCharm = require("@game/ReplicatedStorage/Packages/vide-charm")
local useAtom = VideCharm.useAtom

local create = Vide.create
local Events = require("@game/ReplicatedStorage/Class_Framework/Core/Events").GetNamespace()
local State = require("@game/ReplicatedStorage/Class_Framework/Core/State")

local SelectorUI = require("./UI/Roots/SelectorUI")
local Types = require("@game/ReplicatedStorage/Class_Framework/Core/Types")

local ClientRuntime = {}
ClientRuntime.__index = ClientRuntime

type self = {
	state: State.State,
	access: Types.Access,
	maid: Maid.Maid,
	selectorOpen: Charm.Atom<boolean>,
}
export type ClientRuntime = typeof(setmetatable({} :: self, ClientRuntime))

function ClientRuntime.new(access: Types.Access)
	local state = State.new()
	local self = setmetatable({
		state = state,
		access = access,
		maid = Maid.new(),
		selectorOpen =  Charm.atom(false),
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
				isOpen = useAtom(self.selectorOpen),
				manualButton = self.access.Config.ShowManualButton,
				playerKey = tostring(Players.LocalPlayer.UserId),
				state = self.state,
				setSelectorOpen = function(open: boolean)
					self.selectorOpen(open)
				end,
				requestGroupClass = function(group: string, class: string)
					Events.packets.RequestGroupClass.send({
						group = group,
						class = class,
					})
				end,
				requestClassApply = function(enable: boolean)
					Events.packets.RequestClassApply.send({
						enable = enable,
					})
				end,
				applyClassMode = self.access.Config.ApplyClassMode,
			}),
		}
	end, playerGui)

	self.maid:GiveTask(unmountSelector)
end

function ClientRuntime.WireControllers(self: ClientRuntime, root: Instance)
	for _, controllerModule in root:GetChildren() do
		local controller: Types.InteractionController = require(controllerModule)
		controller.Initialize(self.selectorOpen)
		self.maid:GiveTask(controller.Destroy)
	end
end

function ClientRuntime.Destroy(self: ClientRuntime)
	self.maid:DoCleaning()
end

return ClientRuntime
