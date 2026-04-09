local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local State = require(script.Parent.CharacterState)

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)
local modules = assets:WaitForChild("Modules")
local bridgeNet = require(modules.BridgeNet)

local playerLean = bridgeNet.CreateBridge("PlayerLean")
local bodyAnimRequest = bridgeNet.CreateBridge("BodyAnimRequest")

local RC = {
	headRotationEventCooldown = 0
}
RC.character = nil

function RC.Initialize(params)
	RC.character = params.character

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
	RC.headRotationEventCooldown -= dt
	if RC.headRotationEventCooldown <= 0 and not config.disableHeadRotation then
		RC.headRotationEventCooldown = config.headRotationEventRate
		bodyAnimRequest:Fire(State.Parts.NeckJoint.C1)
	end
end

return RC