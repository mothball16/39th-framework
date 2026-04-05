local assets = game.ReplicatedStorage:WaitForChild("SPH_Assets")
local Packages = game.ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local config = require(assets.GameConfig)


local Player = game.Players.LocalPlayer
local character = Player.Character or Player.CharacterAdded:Wait()
local HRP = character:WaitForChild("HumanoidRootPart")
local Humanoid: Humanoid = character:WaitForChild("Humanoid")
local IsR6 = Humanoid.RigType == Enum.HumanoidRigType.R6
local RootJoint, NeckJoint
if IsR6 then
	RootJoint = HRP:WaitForChild("RootJoint")
	NeckJoint = character.Torso.Neck
else
	RootJoint = character.LowerTorso.Root
	NeckJoint = character.Head.Neck
end

local CharacterState = {
	Parts = {
		IsR6 = IsR6,
		Humanoid = Humanoid,
		RootJoint = RootJoint,
		NeckJoint = NeckJoint,
		Character = character,
		HRP = HRP,
	},

	aimFOVTarget = 	Charm.atom(config.defaultFOV) 		:: Charm.Atom<number>,

	aiming = Charm.atom(false) 							:: Charm.Atom<boolean>,
	equippedTool = Charm.atom(nil) 						:: Charm.Atom<Instance>,
	equipping = Charm.atom(false)						:: Charm.Atom<boolean>,
	sprinting = Charm.atom(false)						:: Charm.Atom<boolean>,

	firstPerson = Charm.atom(false)						:: Charm.Atom<boolean>,
	dead = Charm.atom(false)							:: Charm.Atom<boolean>,
	stance = Charm.atom(0) 								:: Charm.Atom<number>,
	lean = Charm.atom(0) 								:: Charm.Atom<number>,
	moving = Charm.atom(false)							:: Charm.Atom<boolean>,

	freeLook = Charm.atom(false)						:: Charm.Atom<boolean>,
	freeLookRotation = Charm.atom(CFrame.new())			:: Charm.Atom<CFrame>,
	freeLookOffset = Charm.atom(CFrame.new())			:: Charm.Atom<CFrame>,
}

return CharacterState