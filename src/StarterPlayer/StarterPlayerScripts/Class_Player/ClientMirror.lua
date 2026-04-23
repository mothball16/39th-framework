local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Maid = require(Packages.maid)
local CharmSync = require(Packages["charm-sync"])
local Framework = ReplicatedStorage:WaitForChild("Class_Framework")
local Types = require(Framework:WaitForChild("Types"))


local ClientMirror = {}
ClientMirror.__index = ClientMirror


function ClientMirror.new(atoms: Types.Atoms, events: Types.Events)
	local self = setmetatable({}, ClientMirror)
	self.maid = Maid.new()
    self.atoms = atoms
	self.syncer = CharmSync.client({
		atoms = self.atoms,
		ignoreUnhydrated = true,
	})
	self.maid:GiveTask(self.syncer)
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
