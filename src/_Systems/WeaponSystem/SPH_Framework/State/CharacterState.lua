local Framework = script:FindFirstAncestor("SPH_Framework")
local Access = require(Framework.Access)
local Packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = Access.config

local CharState = {}
CharState.__index = CharState

local function resolveParts(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6

	local rootJoint: Motor6D
	local neckJoint: Motor6D
	if isR6 then
		rootJoint = hrp:WaitForChild("RootJoint") :: Motor6D
		neckJoint = (character:WaitForChild("Torso") :: BasePart):WaitForChild("Neck") :: Motor6D
	else
		rootJoint = (character:WaitForChild("LowerTorso") :: BasePart):WaitForChild("Root") :: Motor6D
		neckJoint = (character:WaitForChild("Head") :: BasePart):WaitForChild("Neck") :: Motor6D
	end

	return {
		IsR6 = isR6,
		Humanoid = humanoid,
		RootJoint = rootJoint,
		NeckJoint = neckJoint,
		Character = character,
		HRP = hrp,
	}
end

function CharState.new(character: Model): CharacterState
	local self = setmetatable({
		Parts = resolveParts(character),

		aimFOVTarget = Charm.atom(config.defaultFOV),

		aiming = Charm.atom(false),
		equippedTool = Charm.atom(nil),
		sprinting = Charm.atom(false),

		firstPerson = Charm.atom(false),
		dead = Charm.atom(false),
		stance = Charm.atom(0),
		lean = Charm.atom(0),
		moving = Charm.atom(false),
		vehicleSeated = Charm.atom(false),

		freeLook = Charm.atom(false),
		freeLookRotation = Charm.atom(CFrame.new()),
		freeLookOffset = Charm.atom(CFrame.new()),
	}, CharState)

	return self
end

export type CharacterState = typeof(CharState.new(...))

return CharState
