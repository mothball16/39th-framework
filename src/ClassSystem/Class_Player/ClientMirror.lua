local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Maid = require(Packages.maid)
local CharmSync = require(Packages["charm-sync"])
local State = require(ReplicatedStorage.Class_Framework.Core.State)
local Events = require(ReplicatedStorage.Class_Framework.Core.Events).GetLegacyEvents()
local ClientMirror = {}
ClientMirror.__index = ClientMirror


function ClientMirror.new(state: State.State)
	local self = setmetatable({}, ClientMirror)
	self.maid = Maid.new()
	self.syncer = CharmSync.client({
		atoms = state,
		ignoreUnhydrated = true,
	})
	self.maid:GiveTask(Events.SyncState.OnClientEvent:Connect(function(...)
		self.syncer:sync(...)
	end))

	Events.RequestState:FireServer()
    return self
end

function ClientMirror:Destroy()
    self.maid:DoCleaning()
end

return ClientMirror
