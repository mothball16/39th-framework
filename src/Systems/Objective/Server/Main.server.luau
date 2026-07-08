--!strict
--#selene: allow(incorrect_standard_library_use)
require("@game/ReplicatedStorage/Packages/Charm").flags.frozen = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Access = require("@game/ReplicatedStorage/Systems/Objective/Access")
local ServerRuntime = require("./ServerRuntime")
local ServerRuntimeLocator = require("./ServerRuntimeLocator")
local Types = require("@game/ReplicatedStorage/Systems/Objective/Core/Types")

if Access.Config.DebugMode and RunService:IsStudio() then
	local tests = ReplicatedStorage.Systems.Objective:FindFirstChild("Tests")
	if tests then
		require(ReplicatedStorage.Utility.TestRunner)(tests)
	end
end

local runtime = ServerRuntime.new({ access = Access })
ServerRuntimeLocator.LoadRuntime(runtime)

local configFolder = Access.Assets:FindFirstChild("ObjectiveConfigs")
if configFolder then
	for _, configModule in ipairs(configFolder:GetChildren()) do
		if not configModule:IsA("ModuleScript") then
			continue
		end

		local objective = require(configModule) :: Types.ObjectiveDefinition
		runtime:RegisterObjective(objective)
	end
end
