local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Maid = require(Packages.maid)
local Framework = ReplicatedStorage:WaitForChild("Class_Framework")
local Atoms = require(Framework:WaitForChild("Atoms"))
local Events = require(Framework:WaitForChild("Events"))
local ServerState = require(script.Parent.ServerState)

local state = ServerState.new(Atoms, Events)

