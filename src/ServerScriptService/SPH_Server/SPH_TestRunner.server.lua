--[[
	Runs TestEZ specs under ReplicatedStorage.SPH_Framework.Tests (Studio only).
	Requires `wally install` so DevPackages (TestEZ) exists locally.
]]
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

task.defer(function()
	local devPackages = ReplicatedStorage:FindFirstChild("DevPackages")
	if not devPackages then
		warn("[SPH_TestRunner] ReplicatedStorage.DevPackages missing — run `wally install` to fetch TestEZ.")
		return
	end

	local testEZ = require(devPackages:WaitForChild("TestEZ"))
	local sphCore = ReplicatedStorage:WaitForChild("SPH_Framework", 10)
	if not sphCore then
		warn("[SPH_TestRunner] ReplicatedStorage.SPH_Framework missing.")
		return
	end
	local testsRoot = sphCore:WaitForChild("Tests", 10)
	if not testsRoot then
		warn("[SPH_TestRunner] ReplicatedStorage.SPH_Framework.Tests missing.")
		return
	end

	testEZ.TestBootstrap:run({ testsRoot }, testEZ.Reporters.TextReporter)
end)
