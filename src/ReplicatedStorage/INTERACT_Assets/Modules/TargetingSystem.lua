--[[       
	TARGETING SYSTEM
	DTS/SPH/UCS/INT
	1.1.2

	Made by Jarr (@SrJarr)
--]]

--// Services
local tgtmod = {}
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local collection = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")

local player = game.Players.LocalPlayer
local playerCam = game.Workspace.CurrentCamera

--// Folders
local raycastParams =  RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
tgtmod.RaycastParams = raycastParams

--// String Functions
local function TrimString(str:string):string
	return str:match("^%s*(.-)%s*$")
end

function tgtmod.StringToVector(str:string?):Vector3
	if not str or TrimString(str) == "" then return nil end

	--Remove all brackets/parentheses/commas if present, replace with spaces
	str = str:gsub("[%(%)%[%]{}]", "")
	str = str:gsub(",", " ")

	--Extract all numbers (including negatives and decimals)
	local numbers = {}
	for num in str:gmatch("-?%d+%.?%d*") do
		table.insert(numbers, tonumber(num))
	end

	--Return nil if we didn't find exactly 3 numbers
	if #numbers ~= 3 then return nil end

	--Create and return the Vector3
	return Vector3.new(numbers[1], numbers[2], numbers[3])
end

function tgtmod.VectorToString(pos:Vector3):string
	if not pos then return "--" end
	local posX = string.format("%.1f", pos.X)
	local posY = string.format("%.1f", pos.Y)
	local posZ = string.format("%.1f", pos.Z)
	return posX..", "..posY..", "..posZ
end

-- // Target Data Functions
function tgtmod.ClearTargetData(player:Player, clearPos:boolean, clearObj:boolean)
	--Get value references, clear them if desired
	local targetPos = player:FindFirstChild("Target_Pos") 
	local targetObj = player:FindFirstChild("Target_Obj")

	if targetPos and clearPos then
		targetPos.Value = Vector3.zero
	end

	if targetObj and clearObj then
		targetObj.Value = nil
	end
end

function tgtmod.SetTargetData(player:Player, pos:Vector3?, obj:Instance?):boolean
	--Get value references, create them if nonexistant
	local targetPos = player:FindFirstChild("Target_Pos") 
	local targetObj = player:FindFirstChild("Target_Obj")

	if not targetPos then
		targetPos = Instance.new("Vector3Value")
		targetPos.Name = "Target_Pos"
		targetPos.Parent = player
	end

	if not targetObj then
		targetObj = Instance.new("ObjectValue")
		targetObj.Name = "Target_Obj"
		targetObj.Parent = player
	end

	--Set values
	local lastPos = targetPos.Value
	local lastObj = targetObj.Value

	if pos then
		targetPos.Value = pos 
	end
	if obj then
		targetObj.Value = obj
	end

	return lastPos~=pos, lastObj~=obj 
end

--// Target Check Functions
function tgtmod.IsTargetInFov(fov:number, cameraCFrame:CFrame, targetPosition:Vector3, fovPadding:number, maxRange:number):boolean
	fovPadding = fovPadding or 0

	-- Get camera position and forward direction
	local cameraPosition = cameraCFrame.Position
	local cameraForward = cameraCFrame.LookVector

	-- Calculate direction to target
	local toTarget = (targetPosition - cameraPosition).Unit
	local inRange = (maxRange~=nil and (targetPosition-cameraPosition).Magnitude<maxRange) or maxRange==nil

	-- Calculate angle between camera forward and target direction
	local dotProduct = cameraForward:Dot(toTarget)
	local angle = math.deg(math.acos(dotProduct))

	-- Check if angle is within FOV (with optional padding)
	return angle <= ((fov/2) + fovPadding) and inRange
end

function tgtmod.LineOfSight(obj1:Instance?, obj2:Instance?, filter:{}):boolean
	if not obj1 or not obj2 then return false end
	table.insert(filter, obj1)
	table.insert(filter, obj2)

	--Get positions (handling both parts and CFrames)
	local pos1 = obj1:IsA("Model") and obj1:GetPivot().Position or obj1.Position
	local pos2 = obj2:IsA("Model") and obj2:GetPivot().Position or obj2.Position

	-- Calculate direction and distance
	local difference = pos2 - pos1
	local distance = difference.Magnitude
	local direction = difference.Unit

	--Perform the raycast
	raycastParams.FilterDescendantsInstances = filter
	local result = workspace:Raycast(pos1, direction * distance, raycastParams)
	return result == nil
end

function tgtmod.LeadPosition(velocityHistory:{}, originPos: Vector3, lastPos:Vector3, targetPos: Vector3, targetVel: Vector3, projectileSpeed: number):Vector3
	--Smooth velocity
	table.insert(velocityHistory, targetVel)
	if #velocityHistory > 4 then
		table.remove(velocityHistory, 1)
	end

	local smoothedVel = Vector3.zero
	for _, vel in velocityHistory do
		smoothedVel += vel
	end
	smoothedVel /= math.max(1, #velocityHistory)

	--Calculate lead with smoothed velocity
	local toTarget = targetPos - originPos
	local distance = toTarget.Magnitude
	local travelTime = distance / projectileSpeed
	local predictedPos = targetPos + smoothedVel * travelTime

	--Optional smoothing of position updates (lerp from previous)
	if lastPos then
		local smoothFactor = 0.75 -- lower = smoother but more lag
		predictedPos = lastPos:Lerp(predictedPos, smoothFactor)
	end

	return velocityHistory, predictedPos
end

function tgtmod.PositionFromCompass(origin:Vector3, distance: number, bearing: number): Vector3
	distance = distance --Get the distance in studs instead of meters
	local rads = math.rad(bearing) 
	local dir = Vector3.new(math.sin(rads), 0, -math.cos(rads))

	return Vector3.new(origin.X, origin.Y, origin.Z) + dir * distance
end

function tgtmod.CompassFromPosition(origin:Vector3, target:Vector3): (number, number)
	local offset = target - origin
	offset = Vector3.new(offset.X, 0, offset.Z) -- flatten to XZ

	local distance = offset.Magnitude
	if distance == 0 then
		return 0, 0
	end

	local angle = math.deg(math.atan2(offset.X, -offset.Z))
	if angle < 0 then
		angle += 360
	end

	return distance, angle 
end


--// Misc Functions
function tgtmod.TablesShareElement(t1:{}, t2:{}):boolean
	if type(t1) ~= "table" or type(t2) ~= "table" then return false end

	--Create a lookup table for the first table's elements
	local lookup = {}
	for _, v in t1 do
		lookup[v] = true
	end

	--Check if any element from the second table exists in the lookup
	for _, v in t2 do
		if lookup[v] then return true end
	end

	--No matches found
	return false
end

function tgtmod.GetCharacters():{Model}
	local characters = {}
	for _, player:Player in players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
end

function tgtmod.GetUIDistance(originWorldPos:Vector3, targetUIPos:Vector2):number
	if not originWorldPos or not targetUIPos then return nil end

	--Convert world position to screen space
	local screenPoint, visible = playerCam:WorldToScreenPoint(originWorldPos)
	local screenPosition = Vector2.new(screenPoint.X, screenPoint.Y)
	local distanceFromCenter = (screenPosition - targetUIPos).Magnitude

	return distanceFromCenter
end

tgtmod.ScreenCenter = Vector2.new(playerCam.ViewportSize.X/2, playerCam.ViewportSize.Y/2)
tgtmod.RaycastFilter = {workspace:FindFirstChild("DTS_Workspace"), workspace:FindFirstChild("INTERACT_Workspace")}

return tgtmod