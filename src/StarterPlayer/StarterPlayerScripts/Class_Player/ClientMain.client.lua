local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Charm = require(Packages.Charm)
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Atoms = require(Access.Framework:WaitForChild("Atoms"))
local Events = require(Access.Framework:WaitForChild("Events"))
local ClientMirror = require(script.Parent.ClientMirror)

local mirror = ClientMirror.new(Atoms, Events)

Charm.observe(mirror.atoms.State, function(item, key)
    print(`{key} added: {item}`)
    return function()
        print(`{key} removed`)
    end
end)