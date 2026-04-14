--[[
	Runs TestEZ specs under ReplicatedStorage.SPH_Tests (Studio only).
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
	local testsRoot = ReplicatedStorage:WaitForChild("SPH_Tests", 10)
	if not testsRoot then
		warn("[SPH_TestRunner] ReplicatedStorage.SPH_Tests missing.")
		return
	end

	testEZ.TestBootstrap:run({ testsRoot }, testEZ.Reporters.TextReporter)
end)
