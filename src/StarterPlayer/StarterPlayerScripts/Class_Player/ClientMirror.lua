local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Maid = require(Access.Packages.maid)
local CharmSync = require(Access.Packages["charm-sync"])
local Types = require(Access.Framework.Core.Types)
local State = require(Access.Framework.Core.State)
local Events = require(Access.Framework.Core.Events)
local ClientMirror = {}
ClientMirror.__index = ClientMirror


function ClientMirror.new(state: State.State, events: Events.Events)
	local self = setmetatable({}, ClientMirror)
	self.maid = Maid.new()
	self.syncer = CharmSync.client({
		atoms = state,
		ignoreUnhydrated = true,
	})
	self.maid:GiveTask(events.SyncState.OnClientEvent:Connect(function(...)
		self.syncer:sync(...)
	end))

	events.RequestState:FireServer()
    return self
end

function ClientMirror:Destroy()
    self.maid:DoCleaning()
end

return ClientMirror
