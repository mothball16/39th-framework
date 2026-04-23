local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Maid = require(Access.Packages.maid)
local Atoms = require(Access.Framework:WaitForChild("Atoms"))
local Events = require(Access.Framework:WaitForChild("Events"))
local ServerState = require(script.Parent.ServerState)

local state = ServerState.new(Atoms, Events)

