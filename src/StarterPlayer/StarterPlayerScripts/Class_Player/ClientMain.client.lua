local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))
local Charm = require(Access.Packages.Charm)
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