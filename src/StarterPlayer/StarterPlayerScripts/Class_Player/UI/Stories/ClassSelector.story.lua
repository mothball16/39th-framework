local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Vide = require(Packages.Vide)

local Roots = script.Parent.Parent.Roots
local ClassSelectorUI = require(Roots.ClassSelectorUI)

return function(target: Instance)
    return Vide.mount(function()
        return ClassSelectorUI({
            factionConfigs = {},
            playerFactionIds = {},
            playerClassKeys = {},
            playerClassIds = {},
            classCountsByFaction = {},
        })
    end, target)
end