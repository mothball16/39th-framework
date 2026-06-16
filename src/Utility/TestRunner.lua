return function(path)
    if not game:GetService("RunService"):IsStudio() then
        return
    end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local DevPackages = ReplicatedStorage:WaitForChild("DevPackages")
    local TestEZ = require(DevPackages:WaitForChild("TestEZ"))

    TestEZ.TestBootstrap:run({ path }, TestEZ.Reporters.TextReporterQuiet)
end