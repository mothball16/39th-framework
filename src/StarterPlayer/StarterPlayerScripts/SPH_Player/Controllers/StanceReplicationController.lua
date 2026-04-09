local Utility = game.ReplicatedStorage.Utility
local TagObserver = require(Utility.TagObserver)
local LocalPlayer = game.Players.LocalPlayer
local CollectionService = game:GetService("CollectionService")

local SRC = {
    tagObserver = nil,
    data = {}
}

function SRC.SnapState(entry, value)
    if not entry.joint or not value then return end
    entry.joint.C1 = value
    entry.targetC1 = value
end

function SRC.ToState(entry, value)
    if not entry.joint or not value then return end
    entry.targetC1 = value
end

function SRC.ConnectChar(character: Instance)
    if character == LocalPlayer.Character then return end

    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then return end

        local joint
        if humanoid.RigType == Enum.HumanoidRigType.R6 then
            local torso = character:WaitForChild("Torso", 5)
            joint = torso and torso:WaitForChild("Neck", 5)
        else
            local head = character:WaitForChild("Head", 5)
            joint = head and head:WaitForChild("Neck", 5)
        end

        if not joint then
            warn("StanceReplication: Could not find Neck joint for " .. character.Name)
            return
        end

        -- Verify the character didn't stream out or get destroyed while we were yielding
        if not CollectionService:HasTag(character, "SPH_Character") then return end

        SRC.data[character] = {
            char = character,
            joint = joint,
            humanoid = humanoid,
            targetC1 = joint.C1,
            connections = {
                character:GetAttributeChangedSignal("BodyRot"):Connect(function()
                    local value = character:GetAttribute("BodyRot")
                    if SRC.data[character] then
                        SRC.ToState(SRC.data[character], value)
                    end
                end)
            }
        }
    
        SRC.SnapState(SRC.data[character], character:GetAttribute("BodyRot"))
    end)
end

function SRC.DisconnectChar(character: Instance)
    local data = SRC.data[character]
    if data then
        for _, v in ipairs(data.connections) do
            v:Disconnect()
        end
        SRC.data[character] = nil
    end
end

function SRC.Initialize()
    SRC.tagObserver = TagObserver.new("SPH_Character",{
        onCreated = SRC.ConnectChar,
        onDestroyed = SRC.DisconnectChar
    })
    SRC.tagObserver:Init()
end



return SRC