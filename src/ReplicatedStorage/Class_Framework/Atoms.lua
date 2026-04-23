local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)

return {
    Configuration = Charm.atom({}),
    State = Charm.atom({})
}