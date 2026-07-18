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
        onRender   — (optional) Per-frame update (state, dt, cameraPos),
                     typically for lerping joints. Handlers set state.settled
                     once the joint reaches its target so idle characters cost
                     nothing per frame.
]]

local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TagObserver = require("@game/ReplicatedStorage/Packages/tag-observer")
local LocalPlayer = game.Players.LocalPlayer

local Framework = ReplicatedStorage.Systems.Weapon
local Access = require(Framework.Access)
local config = Access.Config

--------------------------------------------------------------------------------
-- Attribute handler definitions
--------------------------------------------------------------------------------

-- Convergence thresholds: below these the joint snaps to target and the
-- handler stops writing C1 entirely until the attribute changes again.
local SETTLE_ANGLE = 0.005 -- radians (~0.3 degrees)
local SETTLE_DISTANCE = 0.005 -- studs

-- Lerps joint.C1 toward state.targetC1, snapping (and marking settled) when
-- beyond render distance or within the convergence thresholds.
-- ponytail: lean reuses headRotationDistance as its cull distance rather than
-- adding a separate config knob; split it if lean ever needs its own range.
local function lerpJointToward(state, dt: number, cameraPos: Vector3, speed: number)
	local joint = state.joint
	if state.settled or not joint or not joint.Parent or not state.targetC1 then
		return
	end

	local target = state.targetC1
	local dist = (cameraPos - joint.Parent.Position).Magnitude
	if dist > config.headRotationDistance then
		joint.C1 = target
		state.settled = true
		return
	end

	local newC1 = joint.C1:Lerp(target, 1 - math.exp(-speed * dt))
	local delta = newC1:ToObjectSpace(target)
	local _, angle = delta:ToAxisAngle()
	if math.abs(angle) < SETTLE_ANGLE and delta.Position.Magnitude < SETTLE_DISTANCE then
		joint.C1 = target
		state.settled = true
	else
		joint.C1 = newC1
	end
end

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
			if not joint then
				return nil
			end
			return { joint = joint, targetC1 = joint.C1, settled = true }
		end,
		onChanged = function(state, value)
			if state.joint and value then
				state.targetC1 = value
				state.settled = false
			end
		end,
		onRender = function(state, dt, cameraPos)
			lerpJointToward(state, dt, cameraPos, 12)
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
			if not joint then
				return nil
			end
			return {
				joint = joint,
				targetC1 = joint.C1,
				settled = true,
				isR6 = (humanoid.RigType == Enum.HumanoidRigType.R6),
				defaultC1Position = joint.C1.Position,
			}
		end,
		onChanged = function(state, value)
			if not state.joint or value == nil then
				return
			end
			local lean = value
			if state.isR6 then
				state.targetC1 = CFrame.new(-lean / 2, 0, 0)
					* CFrame.Angles(math.rad(90), math.rad(180) + math.rad(17 * lean), 0)
			else
				local pos = state.defaultC1Position
				state.targetC1 = CFrame.new(pos.X, pos.Y, pos.Z) * CFrame.Angles(0, 0, math.rad(17 * lean))
			end
			state.settled = false
		end,
		onRender = function(state, dt, cameraPos)
			lerpJointToward(state, dt, cameraPos, 8)
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
			if not state.humanoid or value == nil then
				return
			end
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
	if character == LocalPlayer.Character then
		return
	end

	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end

		-- Verify the character didn't stream out while we were yielding
		if not CollectionService:HasTag(character, "SPH_Character") then
			return
		end

		local entry = {
			connections = {},
			attrState = {},
		}

		for _, handler in ipairs(ReplicatedAttributes) do
			local state = handler.resolve(character, humanoid)
			if state then
				entry.attrState[handler.attribute] = { state = state, handler = handler }

				table.insert(
					entry.connections,
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
						state.settled = true
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
	local cameraPos = workspace.CurrentCamera.CFrame.Position
	for character, entry in pairs(SRC.data) do
		if not character.Parent then
			SRC.DisconnectChar(character)
		else
			for _, handlerEntry in pairs(entry.attrState) do
				if handlerEntry.handler.onRender then
					handlerEntry.handler.onRender(handlerEntry.state, dt, cameraPos)
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
