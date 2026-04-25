local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local CharmSync = require(Access.Packages["charm-sync"])
local Charm = require(Access.Packages.Charm)
local Maid = require(Access.Packages.maid)
local Types = require(Access.Framework.Core:WaitForChild("Types"))

local ServerSyncer = {}
ServerSyncer.__index = ServerSyncer

function ServerSyncer.new(atoms, events: Types.Events)
	local self = setmetatable({}, ServerSyncer)
	self.maid = Maid.new()
	self.atoms = atoms
	self.syncer = CharmSync.server({
		atoms = self.atoms,
		interval = 0,
		preserveHistory = false,
		autoSerialize = true,
	})
	self.maid:GiveTask(self.syncer:connect(function(player, ...)
		print(...)
		events.SyncState:FireClient(player, ...)
	end))

	self.maid:GiveTask(events.RequestState.OnServerEvent:Connect(function(player)
		self.syncer:hydrate(player)
	end))

	return self
end

function ServerSyncer:Destroy()
	self.maid:DoCleaning()
end

return ServerSyncer
