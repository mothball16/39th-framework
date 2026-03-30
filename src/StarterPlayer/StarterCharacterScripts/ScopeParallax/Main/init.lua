local Main = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local camera = workspace.CurrentCamera

local Detect = require(script:WaitForChild("Detect"))
local Patcher = require(script:WaitForChild("Patcher"))

function Main.init()
	Patcher.init()
	Detect.init()
end

return Main