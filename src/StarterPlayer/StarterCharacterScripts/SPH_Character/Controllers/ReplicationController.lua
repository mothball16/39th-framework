local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local State = require(script.Parent.CharacterState)

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local modules = assets:WaitForChild("Modules")
local bridgeNet = require(modules.BridgeNet)

local playerLean = bridgeNet.CreateBridge("PlayerLean")
local bodyAnimRequest = bridgeNet.CreateBridge("BodyAnimRequest")

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
		if lean ~= oldLean then
			playerLean:Fire(lean)
		end
	end)
end

function ReplicationController.ReplicateHeadRotation(c1)
	bodyAnimRequest:Fire(c1)
end

return ReplicationController