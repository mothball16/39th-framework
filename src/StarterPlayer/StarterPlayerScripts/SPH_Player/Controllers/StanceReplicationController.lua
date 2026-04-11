--[[
    StanceReplicationController

    Attribute-based replication for character state visible to other players.
    Uses TagObserver to detect SPH_Character instances and subscribes to
    attribute changes for smooth, lerped replication of body rotation, lean,
    and stance.

    To replicate a new attribute, add an entry to ReplicatedAttributes:
        attribute  — The attribute name set on the character instance.
        resolve    — Returns per-character state for this handler, or nil to skip.
        onChanged  — Called when the attribute value changes.
        onRender   — (optional) Per-frame update, typically for lerping joints.
]]

local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utility = ReplicatedStorage.Utility
local TagObserver = require(Utility.TagObserver)
local LocalPlayer = game.Players.LocalPlayer

local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local config = require(assets.GameConfig)

--------------------------------------------------------------------------------
-- Attribute handler definitions
--------------------------------------------------------------------------------

local ReplicatedAttributes = {
    -- Body rotation (head / neck joint)
    {
        attribute = "BodyRot",
        resolve = function(character, humanoid)
            local joint
            if humanoid.RigType == Enum.HumanoidRigType.R6 then
                local torso = character:WaitForChild("Torso", 5)
                joint = torso and torso:WaitForChild("Neck", 5)
            else
                local head = character:WaitForChild("Head", 5)
                joint = head and head:WaitForChild("Neck", 5)
            end
            if not joint then return nil end
            return { joint = joint, targetC1 = joint.C1 }
        end,
        onChanged = function(state, value)
            if state.joint and value then
                state.targetC1 = value
            end
        end,
        onRender = function(state, dt)
            if state.joint and state.joint.Parent and state.targetC1 then
                local dist = (workspace.CurrentCamera.CFrame.Position - state.joint.Parent.Position).Magnitude
                if dist <= config.headRotationDistance then
                    state.joint.C1 = state.joint.C1:Lerp(state.targetC1, 1 - math.exp(-12 * dt))
                end
            end
        end,
    },

    -- Lean (torso tilt via root joint)
    {
        attribute = "Lean",
        resolve = function(character, humanoid)
            local joint
            if humanoid.RigType == Enum.HumanoidRigType.R6 then
                local hrp = character:WaitForChild("HumanoidRootPart", 5)
                joint = hrp and hrp:WaitForChild("RootJoint", 5)
            else
                local upperTorso = character:WaitForChild("UpperTorso", 5)
                joint = upperTorso and upperTorso:WaitForChild("Waist", 5)
            end
            if not joint then return nil end
            return {
                joint = joint,
                targetC1 = joint.C1,
                isR6 = (humanoid.RigType == Enum.HumanoidRigType.R6),
                defaultC1Position = joint.C1.Position,
            }
        end,
        onChanged = function(state, value)
            if not state.joint or value == nil then return end
            local lean = value
            if state.isR6 then
                state.targetC1 = CFrame.new(-lean / 2, 0, 0)
                    * CFrame.Angles(math.rad(90), math.rad(180) + math.rad(17 * lean), 0)
            else
                local pos = state.defaultC1Position
                state.targetC1 = CFrame.new(pos.X, pos.Y, pos.Z)
                    * CFrame.Angles(0, 0, math.rad(17 * lean))
            end
        end,
        onRender = function(state, dt)
            if state.joint and state.joint.Parent and state.targetC1 then
                state.joint.C1 = state.joint.C1:Lerp(state.targetC1, 1 - math.exp(-8 * dt))
            end
        end,
    },

    -- Stance (crouch / prone — tweens HipHeight for observers)
    {
        attribute = "Stance",
        resolve = function(character, humanoid)
            return {
                humanoid = humanoid,
                baseHipHeight = humanoid.HipHeight,
                isR6 = (humanoid.RigType == Enum.HumanoidRigType.R6),
            }
        end,
        onChanged = function(state, value)
            if not state.humanoid or value == nil then return end
            local targetHeight
            if value == 0 then
                targetHeight = state.isR6 and 0 or state.baseHipHeight
            elseif value == 1 then
                targetHeight = state.isR6 and 0 or state.baseHipHeight
            elseif value == 2 then
                targetHeight = state.isR6 and -2 or (state.baseHipHeight * 0.5)
            else
                return
            end
            TweenService:Create(
                state.humanoid,
                TweenInfo.new(config.stanceChangeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { HipHeight = targetHeight }
            ):Play()
        end,
        -- No onRender — TweenService handles the interpolation.
    },
}

--------------------------------------------------------------------------------
-- Controller
--------------------------------------------------------------------------------

local SRC = {
    tagObserver = nil,
    data = {},
}

function SRC.ConnectChar(character: Instance)
    if character == LocalPlayer.Character then return end

    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then return end

        -- Verify the character didn't stream out while we were yielding
        if not CollectionService:HasTag(character, "SPH_Character") then return end

        local entry = {
            connections = {},
            attrState = {},
        }

        for _, handler in ipairs(ReplicatedAttributes) do
            local state = handler.resolve(character, humanoid)
            if state then
                entry.attrState[handler.attribute] = { state = state, handler = handler }

                table.insert(entry.connections,
                    character:GetAttributeChangedSignal(handler.attribute):Connect(function()
                        local value = character:GetAttribute(handler.attribute)
                        handler.onChanged(state, value)
                    end)
                )

                -- Snap to initial value so the character doesn't pop in at defaults
                local initial = character:GetAttribute(handler.attribute)
                if initial ~= nil then
                    handler.onChanged(state, initial)
                    -- For joint-driven handlers, apply immediately (skip first-frame lerp)
                    if state.joint and state.targetC1 then
                        state.joint.C1 = state.targetC1
                    end
                end
            end
        end

        SRC.data[character] = entry
    end)
end

function SRC.DisconnectChar(character: Instance)
    local entry = SRC.data[character]
    if entry then
        for _, conn in ipairs(entry.connections) do
            conn:Disconnect()
        end
        SRC.data[character] = nil
    end
end

function SRC.UpdateRender(dt)
    debug.profilebegin("SPH.StanceReplication.UpdateRender")
    for character, entry in pairs(SRC.data) do
        if not character.Parent then
            SRC.DisconnectChar(character)
        else
            for _, handlerEntry in pairs(entry.attrState) do
                if handlerEntry.handler.onRender then
                    handlerEntry.handler.onRender(handlerEntry.state, dt)
                end
            end
        end
    end
    debug.profileend()
end

function SRC.Initialize()
    SRC.tagObserver = TagObserver.new("SPH_Character", {
        onCreated = SRC.ConnectChar,
        onDestroyed = SRC.DisconnectChar,
    })
    SRC.tagObserver:Init()
end

return SRC
