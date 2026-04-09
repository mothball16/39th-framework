local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local State = require(script.Parent.CharacterState)

local ReplicationController = {}
ReplicationController.character = nil

function ReplicationController.Initialize(params)
	ReplicationController.character = params.character

	Charm.subscribe(State.sprinting, function(sprinting)
		if ReplicationController.character then ReplicationController.character:SetAttribute("Sprinting", sprinting) end
	end)

	Charm.subscribe(State.aiming, function(aiming)
		if ReplicationController.character then ReplicationController.character:SetAttribute("Aiming", aiming) end
	end)

	Charm.subscribe(State.lean, function(lean, oldLean)
		if lean ~= oldLean and ReplicationController.character then
			ReplicationController.character:SetAttribute("Lean", lean)
		end
	end)

	Charm.subscribe(State.stance, function(stance, oldStance)
		if stance ~= oldStance and ReplicationController.character then
			ReplicationController.character:SetAttribute("Stance", stance)
		end
	end)
end

function ReplicationController.ReplicateHeadRotation(c1)
	if ReplicationController.character then
		ReplicationController.character:SetAttribute("BodyRot", c1)
	end
end

return ReplicationController
