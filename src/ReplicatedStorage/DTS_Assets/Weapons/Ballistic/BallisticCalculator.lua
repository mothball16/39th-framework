--[[       
DRAGOON TANK SYSTEM
Ballistic Calculator
1.1.1

With additions and improvements from:
- Widukindazz & Prestigeless (Zeroing, ballistic calculator)
--]]

--// Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local BCalc = {}

local player = game.Players.LocalPlayer
local playerCam = game.Workspace.CurrentCamera

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = {game.Workspace.DTS_Workspace, game.Workspace.Vehicles}

--[[
UNUSED

written by jarr & chatgpt 

function BCalc.CalculateAim(aimPos:Vector3, tBase:CFrame, tPivot:CFrame, gBase:CFrame, gPivot:CFrame, shellVelocity:number, aimDist:number, turretLimit:{number}, gunLimit:{number})
	--Recalculate aim position at given distance
	local targetPos = (aimPos - tPivot.Position).Unit * aimDist

	--Transform target into local space of the turret base for yaw calculation
	local turretLocal = tBase:PointToObjectSpace(targetPos)
	local yaw = math.deg(math.atan2(turretLocal.X, turretLocal.Z))

	--Transform target into local space of the gun base for pitch calculation
	local gunLocal = gBase:PointToObjectSpace(targetPos)
	local pitch --Direct fire
	local pitch2 --Indirect fire
	
	--Solve basic ballistic pitch
	local g = workspace.Gravity
	local v = shellVelocity*3.5
	local y = gunLocal.Y
	local hDist = math.sqrt(gunLocal.X ^ 2 + gunLocal.Z ^ 2)

	local inside = v ^ 4 - g * (g * hDist ^ 2 + 2 * y * v ^ 2)
	if inside >= 0 then
		local root = math.sqrt(inside)
		local thetaLow = math.atan((v ^ 2 - root) / (g * hDist)) -- direct fire
		local thetaHigh = math.atan((v ^ 2 + root) / (g * hDist)) -- indirect fire

		pitch = math.deg(thetaLow)
		pitch2 = math.deg(thetaHigh)
	else
		local thetaNil = math.deg(math.atan2(y, hDist))
		pitch = thetaNil
		pitch2 = thetaNil
	end
	
	--Limit things
	pitch = math.clamp(pitch, gunLimit[1], gunLimit[2])
	yaw = math.clamp(yaw, turretLimit[1], turretLimit[2])

	return yaw, pitch, pitch2
end
--]]

function BCalc.CalculateParallaxCompensation(sightPosition, barrelPosition, targetDistance)
	local barrelToTargetDirection = (Vector3.new(0, 0, targetDistance) - barrelPosition).unit

	-- Find the point along this direction where the barrel will hit
	local hitPoint = barrelPosition + barrelToTargetDirection * targetDistance

	-- Direction vector from sight to the hit point
	local sightToHitDirection = (hitPoint - sightPosition).unit

	-- Calculate the angle between the sight's forward direction and the hit point direction
	local deltaY = hitPoint.Y - sightPosition.Y
	local angle = math.deg(math.atan2(deltaY, targetDistance))

	return angle
end

function BCalc.PredictTarget(origin:CFrame, muzzleVelocity, acceleration:Vector3, numSteps, stepDuration)
	local points = {}
	local position = origin.Position
	local velocity =   origin.LookVector * muzzleVelocity

	table.insert(points, position)
	for i = 1, numSteps do
		-- Predict next position
		local newVelocity = velocity + acceleration * stepDuration
		local displacement = (velocity + newVelocity) * 0.5 * stepDuration -- Trapezoidal integration
		local nextPosition = position + displacement

		--Raycast from current to next position
		local result = workspace:Raycast(position, nextPosition - position, rayParams)
		if result then
			table.insert(points, result.Position)
			return points, result.Instance -- Return hit position and part
		end

		--Update for next step
		position = nextPosition
		velocity = newVelocity
		table.insert(points, position)
	end

	-- No hit detected within maxTime
	return points, nil
end

function BCalc.FindAngleToShootAt(distance, projectileSpeed, gravity, StartAngle)
	local distX = distance * 3.5  --Horizontal distance
	local distY = (distance > 0) and -3 or 0   --Vertical distance

	StartAngle = StartAngle and math.rad(StartAngle) or 0

	local speed2 = projectileSpeed^2
	local speed4 = projectileSpeed^4
	local gx = gravity * distX

	local root = speed4 - gravity * (gravity * distX * distX + 2 * distY * speed2)
	if root < 0 then
		return 0, 0
	end

	root = math.sqrt(root)

	local lowAng = math.atan2(speed2 - root, gx)
	local highAng = math.atan2(speed2 + root, gx)

	local deltaLowAng = lowAng
	local deltaHighAng = highAng

	return math.deg(deltaLowAng), math.deg(deltaHighAng)
end

function BCalc.FindBDCOffset(distance, shellVelocity, zero, ignoreZero,frame, CurVehDeg)
	local zeroAngle = BCalc.FindAngleToShootAt(zero, shellVelocity, workspace.Gravity, CurVehDeg)
	local targetAngle = BCalc.FindAngleToShootAt(distance, shellVelocity, workspace.Gravity, CurVehDeg)
	local height = frame.AbsoluteSize.Y
	local zeroOffset = (not ignoreZero and zeroAngle/playerCam.FieldOfView*height) or 0 --degrees/fov*height
	local targetOffset = targetAngle/playerCam.FieldOfView*height --degrees/fov*height
	return (targetOffset - zeroOffset)
end

return BCalc
