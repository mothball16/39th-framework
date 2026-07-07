local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Framework = ReplicatedStorage.Systems.Weapon
local Access = require(Framework.Access)
local CharacterStateModule = require(Framework.State.CharacterState)

local config = Access.config
local NetworkEvents = require(Framework.Network.NetworkEvents)
local P = NetworkEvents.packets

local ReplicationController = {}
ReplicationController.__index = ReplicationController

type self = {
	character: Model,
	state: CharacterStateModule.CharacterState,
	headRotationEventCooldown: number,
}

export type ReplicationController = typeof(setmetatable({} :: self, ReplicationController))

function ReplicationController.new(params: {
	character: Model,
	state: CharacterStateModule.CharacterState,
}): ReplicationController
	local self = setmetatable(
		{
			character = params.character,
			state = params.state,
			headRotationEventCooldown = 0,
		} :: self,
		ReplicationController
	)

	Charm.subscribe(self.state.sprinting, function(sprinting)
		self.character:SetAttribute("Sprinting", sprinting)
	end)

	Charm.subscribe(self.state.aiming, function(aiming)
		self.character:SetAttribute("Aiming", aiming)
	end)

	Charm.subscribe(self.state.lean, function(lean, oldLean)
		if lean ~= oldLean then
			P.PlayerLean.send({ lean = lean })
		end
	end)

	return self
end

function ReplicationController.UpdateRender(self: ReplicationController, dt: number)
	debug.profilebegin("SPH.CharacterReplication.UpdateRender")
	self.headRotationEventCooldown -= dt
	if self.headRotationEventCooldown <= 0 and not config.disableHeadRotation then
		self.headRotationEventCooldown = config.headRotationEventRate
		P.BodyAnimRequest.send({ neckC1 = self.state.Parts.NeckJoint.C1 })
		local char = Players.LocalPlayer.Character
		if char then
			char:SetAttribute("BodyRot_Client", self.state.Parts.NeckJoint.C1)
		end
	end
	debug.profileend()
end

return ReplicationController
