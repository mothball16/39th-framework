local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Framework = ReplicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local CharacterStateModule = require(Framework.State.CharacterState)

local config = Access.config
local Events = require(Framework.Network.Events)
local P = Events.GetNamespace().packets

local RC = {
	headRotationEventCooldown = 0
}
RC.character = nil
local State: CharacterStateModule.CharacterState

function RC.Initialize(params)
	RC.character = params.character
	State = params.state

	Charm.subscribe(State.sprinting, function(sprinting)
		if RC.character then RC.character:SetAttribute("Sprinting", sprinting) end
	end)

	Charm.subscribe(State.aiming, function(aiming)
		if RC.character then RC.character:SetAttribute("Aiming", aiming) end
	end)

	Charm.subscribe(State.lean, function(lean, oldLean)
		if lean ~= oldLean then
			P.PlayerLean.send({ lean = lean })
		end
	end)
end

function RC.UpdateRender(dt)
	debug.profilebegin("SPH.CharacterReplication.UpdateRender")
	RC.headRotationEventCooldown -= dt
	if RC.headRotationEventCooldown <= 0 and not config.disableHeadRotation then
		RC.headRotationEventCooldown = config.headRotationEventRate
		P.BodyAnimRequest.send({ neckC1 = State.Parts.NeckJoint.C1 })
		local char = game.Players.LocalPlayer.Character
		if char then
			char:SetAttribute("BodyRot_Client", State.Parts.NeckJoint.C1)
		end
	end
	debug.profileend()
end

return RC