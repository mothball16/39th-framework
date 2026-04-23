local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Access = require(ReplicatedStorage:WaitForChild("Class_Access"))

local Types = require(script.Parent.Parent.Types)

local Tool: Types.IClassItem = {
    Identifier = "Tool",
}

function Tool.Assign(player: Player)
    
end

function Tool.Unassign()
    
end

return Tool