local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local CharacterStateModule = require(ReplicatedStorage.SPH_Framework.State.CharacterState)

local sph = require(ReplicatedStorage.SPH_Framework.GameAccess)
local assets = sph.assets
local framework = sph.framework
local config = sph.config
local bridgeNet = require(framework.Network.BridgeNet)

local playerLean = bridgeNet.CreateBridge("PlayerLean")
local bodyAnimRequest = bridgeNet.CreateBridge("BodyAnimRequest")

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
			playerLean:Fire(lean)
		end
	end)
end

function RC.UpdateRender(dt)
	debug.profilebegin("SPH.CharacterReplication.UpdateRender")
	RC.headRotationEventCooldown -= dt
	if RC.headRotationEventCooldown <= 0 and not config.disableHeadRotation then
		RC.headRotationEventCooldown = config.headRotationEventRate
		bodyAnimRequest:Fire(State.Parts.NeckJoint.C1)
	end
	debug.profileend()
end

return RC