local sph = require(game.ReplicatedStorage.SPH_Framework.Core.GameAccess)
local Packages = game.ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = sph.config

local CharState = {}
CharState.__index = CharState

type self = {
	Parts: {
		IsR6: boolean,
		Humanoid: Humanoid,
		RootJoint: Motor6D,
		NeckJoint: Motor6D,
		Character: Model,
		HRP: BasePart,
	},

	aimFOVTarget: Charm.Atom<number>,

	aiming: Charm.Atom<boolean>,
	equippedTool: Charm.Atom<Instance?>,
	sprinting: Charm.Atom<boolean>,

	firstPerson: Charm.Atom<boolean>,
	dead: Charm.Atom<boolean>,
	stance: Charm.Atom<number>,
	lean: Charm.Atom<number>,
	moving: Charm.Atom<boolean>,
	vehicleSeated: Charm.Atom<boolean>,

	freeLook: Charm.Atom<boolean>,
	freeLookRotation: Charm.Atom<CFrame>,
	freeLookOffset: Charm.Atom<CFrame>,
}

export type CharacterState = typeof(setmetatable({}, CharState))

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
	} :: self, CharState)

	return self
end

return CharState
