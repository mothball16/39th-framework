--[[       
DRAGOON TANK SYSTEM
HUD Module
1.2.0

With additions and improvements from:
- Widukindazz & Prestigeless (Zeroing, ballistic calculator)
--]]

--// Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local userInput = game:GetService("UserInputService")
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local tweens = game:GetService("TweenService")
local guiservice = game:GetService("GuiService")
local HUDMod = {}

--// Folders
local assets = replicatedStorage.DTS_Assets
local events = assets.Events
local fx = assets.FX
local modules = assets.Modules
local wmodules = assets.Weapons
local amodules = assets.Addons
local projectiles = assets.Projectiles

local bcalc = require(wmodules.Ballistic.BallisticCalculator)
local config = require(assets.GlobalSettings)
local player = game.Players.LocalPlayer
local playerCam = game.Workspace.CurrentCamera

local topInset = guiservice:GetGuiInset()
local rng = Random.new()
local dtCount = 0
local cache = os.clock()
local lastY = 0
local units = {
	["N"] = -math.pi * 4 / 4,
	["NE"] = -math.pi * 3 / 4,
	["E"]= -math.pi * 2 / 4,
	["SE"] = -math.pi * 1 / 4,
	["S"] = math.pi * 0 / 4,
	["SW"] = math.pi * 1 / 4,
	["W"] = math.pi * 2 / 4,
	["NW"] = math.pi * 3 / 4
}
local fireModeNames = {"SAFE", "[SEMI]", "[AUTO]", "[BURST]", "[MANUAL]"}
local uiElements = {"Frame", "TextLabel", "ImageLabel", "ScrollingFrame"}

local predictSteps = 60
local predictTime = 1/4 --time per step, rn set at X steps of 1/8 of a second each

--// Functions
local function SplitNumber(number, startLength) --thanks AI for doing the stuff im too lazy for
	local numberStr = tostring(number)
	local leadingZeros = ""
	local restOfNumber = numberStr

	-- Calculate the number of leading zeros needed
	local totalLength = startLength
	local leadingZerosCount = totalLength - #numberStr

	-- Add leading zeros if necessary
	if leadingZerosCount > 0 then
		for i = 1, leadingZerosCount do
			leadingZeros = leadingZeros .. "0"
		end
	end

	-- If the number is longer than 3 digits, take the last 3 digits only
	if #numberStr > totalLength then
		restOfNumber = numberStr:sub(-totalLength)
		leadingZeros = ""
	end

	return {leadingZeros, restOfNumber}
end

local function GetUDimDistance(pos1:UDim2, pos2:UDim2)
	local vec1 = Vector2.new(pos1.X.Offset, pos1.Y.Offset)
	local vec2 = Vector2.new(pos2.X.Offset, pos2.Y.Offset)
	return (vec1 - vec2).Magnitude
end

local function GetUISizeByDistance(startSize: UDim2, distance: number, minScale: number?, maxDistance: number?)
	minScale = minScale or 0.1
	maxDistance = maxDistance or 1000

	-- Clamp distance to avoid going below minScale
	local scale = 1 - math.clamp(distance / maxDistance, 0, 1)
	local finalScale = math.max(scale, minScale)

	-- Scale the UI size
	return UDim2.new(
		startSize.X.Scale * finalScale,
		startSize.X.Offset * finalScale,
		startSize.Y.Scale * finalScale,
		startSize.Y.Offset * finalScale
	)
end

local function GetPointsInCircle(origin:CFrame, radius:number, definition:number): {Vector3}
	local points = {}
	for i = 0, definition - 1 do
		local angle = (i / definition) * math.pi * 2
		local localPoint = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local worldPoint = origin:PointToWorldSpace(localPoint)
		table.insert(points, worldPoint)
	end
	return points
end

local function GetPointByAngles(origin: CFrame, distance: number, rotDeg: number, elevDeg: number): Vector3
	local rot = math.rad(rotDeg)
	local elev = math.rad(elevDeg)

	--Direction vector in local space (spherical coordinates)
	local x = math.cos(elev) * math.cos(rot)
	local y = math.sin(elev)
	local z = math.cos(elev) * math.sin(rot)
	local dir = Vector3.new(x, y, z).Unit

	return origin:PointToWorldSpace(dir * distance)
end

local function GetFormattedPos(pos:Vector3)
	if not pos then return "--" end
	local posX = string.format("%.1f", pos.X)
	local posY = string.format("%.1f", pos.Y)
	local posZ = string.format("%.1f", pos.Z)
	return posX..", "..posY..", "..posZ
end

local function DrawLine(object:Frame, posA:Vector3, posB:Vector3)
	if not object or not posA or not posB then return end

	local pointAraw, pointAVis = playerCam:WorldToViewportPoint(posA)
	local pointA = Vector2.new(pointAraw.X, pointAraw.Y)
	local pointBraw, pointBVis = playerCam:WorldToViewportPoint(posB)
	local pointB = Vector2.new(pointBraw.X, pointBraw.Y)
	local dist = (pointA - pointB).Magnitude
	local midpoint = (pointA + pointB)/2
	local angle = math.atan2(pointB.Y-pointA.Y, pointB.X-pointA.X)
	object.Visible = pointAVis or pointBVis
	object.Size = UDim2.new(0,dist,0, object.Size.Y.Offset)
	object.Position = UDim2.new(0, midpoint.X, 0, midpoint.Y )--+ topInset.Y
	object.Rotation = math.deg(angle)
end

local function DrawLine2(object:Frame, fromCF:CFrame, toPos:Vector3) --Takes a CFrame to point in that direction, using the second position as the lenght defining variable
	local pos1 = fromCF.Position
	local pos2 = toPos

	local worldDist = (pos1 - pos2).Magnitude
	local endWorldPos = pos1 + fromCF.LookVector * worldDist

	-- Project world to screen
	local start2D, onScreen1 = playerCam:WorldToViewportPoint(pos1)
	local end2D, onScreen2 = playerCam:WorldToViewportPoint(endWorldPos)
	object.Visible = onScreen1 and onScreen2
	if not object.Visible then return end 

	local startVec2 = Vector2.new(start2D.X, start2D.Y)
	local endVec2   = Vector2.new(end2D.X, end2D.Y)

	local dir = endVec2 - startVec2
	local length = dir.Magnitude
	local midpoint = (startVec2 + endVec2) / 2

	object.Size = UDim2.new(0, length, 0, object.Size.Y.Offset)
	object.Position = UDim2.new(0, midpoint.X, 0, midpoint.Y)
	object.Rotation = math.deg(math.atan2(dir.Y, dir.X))
end

local function ReferenceCircle(uiObj, vehicleCenter:CFrame, turretCenter:CFrame, yaw:number, pitch:number)
	local trueCF = vehicleCenter * CFrame.Angles(0, -90, 0)
	local trueYaw = turretCenter * CFrame.Angles(0, yaw, 0)
	local truePitch = turretCenter * CFrame.Angles(0, 0, pitch)
	local points = GetPointsInCircle(turretCenter, 20, 8)

	for i=1, #points do
		if i<=1 then continue end
		--if i>30 then break end --or (point - muzzleCFrame.Position).Magnitude > distance 

		local newSegment = uiObj:FindFirstChild("CastSegment_"..i) or uiObj.CastSegment_Example:Clone()
		local thisPoint = points[i]
		local nextPoint = i>=#points and points[1] or points[i+1]

		if thisPoint and nextPoint then
			newSegment.Name = "CastSegment_"..i
			newSegment.Parent = uiObj
			DrawLine(newSegment, thisPoint, nextPoint)
		else
			newSegment.Visible = false
		end
	end
	
	if yaw then
		local yawPos = GetPointByAngles(turretCenter, 16, yaw, 0)
		local yawSegment = uiObj:FindFirstChild("CastSegment_Yaw") or uiObj.CastSegment_Example:Clone()
		yawSegment.Name = "CastSegment_Yaw"
		yawSegment.Parent = uiObj
		DrawLine(yawSegment, turretCenter.Position, yawPos)
	end
	if pitch then
		local pitchPos = GetPointByAngles(turretCenter, 16, yaw, pitch)
		local pitchSegment = uiObj:FindFirstChild("CastSegment_Pitch") or uiObj.CastSegment_Example:Clone()
		pitchSegment.Name = "CastSegment_Pitch"
		pitchSegment.Parent = uiObj
		DrawLine(pitchSegment, turretCenter.Position, pitchPos)
	end
end

local function PredictTrajectory(uiObj, wpnConfig, muzzleCFrame)
	local flightTime = predictTime * (300/wpnConfig.ShellVelocity) 

	local points, targetObj = bcalc.PredictTarget(muzzleCFrame, wpnConfig.ShellVelocity*3.5, Vector3.new(0, -workspace.Gravity, 0), predictSteps, flightTime)
	if #points <= 2 then 
		for _, segment in uiObj:GetChildren() do
			if segment.Name=="CastSegment_Example" then continue end
			segment.Visible = false
		end
		return 
	end

	local lineColor = (targetObj==nil and Color3.fromRGB(152, 52, 52)) or (targetObj~=nil and Color3.fromRGB(255, 255, 255))

	for i=1, predictSteps do
		if i<=1 then continue end
		--if i>30 then break end --or (point - muzzleCFrame.Position).Magnitude > distance 

		local newSegment = uiObj:FindFirstChild("CastSegment_"..i) or uiObj.CastSegment_Example:Clone()
		local prevPoint = points[i-1]
		local nextPoint = points[i]

		if prevPoint and nextPoint then
			newSegment.Name = "CastSegment_"..i
			newSegment.Parent = uiObj
			newSegment.BackgroundColor3 = lineColor
			DrawLine(newSegment, prevPoint, nextPoint)
		else
			newSegment.Visible = false
		end
	end
	local lastPoint = points[#points]
	local absDist = (muzzleCFrame.Position-lastPoint).Magnitude

	local targetPos, targetVis = playerCam:WorldToViewportPoint(lastPoint)
	uiObj.HitPos.Position = UDim2.new(0, targetPos.X, 0, targetPos.Y)
	uiObj.HitPos.Visible = targetVis
	uiObj.HitPos.Circle.ImageColor3 = lineColor--targetObj==nil
	uiObj.HitPos.Size = GetUISizeByDistance(UDim2.new(0, 34, 0, 34), absDist, 0.05, wpnConfig.RangefinderMax)
end

local function GetCompassData()
	local look = playerCam.CFrame.LookVector.Unit
	local CoordinateDirection = CFrame.Angles(0,math.rad(-90),0):VectorToWorldSpace(look)
	return CoordinateDirection, look
end

function HUDMod.RestrictAngle(angle)
	if angle < -math.pi then
		return angle + math.pi * 2
	elseif angle > math.pi then
		return angle - math.pi * 2
	else
		return angle
	end
end

local function UpdateCompass2(uiObj, CoordinateDirection) --Digital compass label
	local displayAngle = math.deg(math.atan2(CoordinateDirection.Z, CoordinateDirection.X)) % 360
	local bearingDigits = SplitNumber(math.floor(displayAngle), 3)
	uiObj.Text = [[<font transparency="0.5">]]..bearingDigits[1]..[[</font>]]..bearingDigits[2] --.."°"
end

local function UpdateCompass(uiObj, dt, look) --Compass band
	local lookY = math.atan2(look.Z, look.X)
	local diffY = HUDMod.RestrictAngle(lookY - lastY)
	lookY = HUDMod.RestrictAngle(lastY+diffY * dt * 10)
	lastY = lookY
	for unitName, rot in pairs(units) do
		local unit = uiObj:FindFirstChild(unitName)
		if not unit then continue end

		rot = HUDMod.RestrictAngle(lookY - rot)
		if 0 < math.sin(rot) then
			local cosRot = math.cos(rot)
			local cosRot2 = cosRot * cosRot
			unit.Visible = true
			unit.Position = UDim2.new(0.5 + cosRot * 0.6, unit.Position.X.Offset, 0, 3)
			unit.TextTransparency = -0.25 + 1.25 * cosRot2			
		else
			unit.Visible = false
		end
	end
end

local function UpdateCrosshairs(wpnGui, aimPos, cannonCFrame:CFrame)
	local cross2Raw, cross2Vis = playerCam:WorldToViewportPoint(aimPos) --Camera center or mouse position
	local cross2 = UDim2.new(0, cross2Raw.X, 0, cross2Raw.Y)

	local distOffset = (playerCam:GetRenderCFrame().Position-cannonCFrame.Position).Magnitude
	local aimDist = (playerCam:GetRenderCFrame().Position - aimPos).Magnitude-distOffset
	local cross1WPos = cannonCFrame.Position + cannonCFrame.LookVector * aimDist
	local cross1Raw, cross1Vis = playerCam:WorldToViewportPoint(cross1WPos) --cannon LOS
	local cross1 = UDim2.new(0, cross1Raw.X, 0, cross1Raw.Y)

	return cross1, cross1Vis, (GetUDimDistance(cross2, cross1)<10 and cross1) or cross2, cross2Vis
end

function HUDMod.UpdateReload(duration, began) --wpnConfig.ReloadTime, weapon:GetAttribute("internal_ReloadStart")
	if not duration or not began then return 0, false end

	local currentTime = os.clock()
	local elapsed = currentTime - began
	local progress = math.clamp(elapsed/duration, 0, 1)
	local isReloading = progress < 1
	return progress, isReloading
end

function HUDMod.UpdateSights(weapon, wpnGui, inGunsights, targetPos, cannonPos, muzzleCFrame, camCFrame, targetDist, mouseDelta, dt, wpnConfig)
	if not wpnGui or not wpnGui.Visible or not wpnConfig then return end --dont update the UI if its not visible

	--Vehicle
	local vehicle:Model = weapon and weapon.Parent and weapon.Parent.Parent
	local vicPos = vehicle and vehicle:GetPivot().Position
	local freeAim = vehicle and vehicle:GetAttribute("internal_freeAim")

	--Crosshair position
	local cross1Pos = UDim2.new()
	local cross1Vis = false
	local cross2Pos = UDim2.new()
	local cross2Vis = false
	if muzzleCFrame and targetPos then
		cross1Pos, cross1Vis, cross2Pos, cross2Vis = UpdateCrosshairs(wpnGui, targetPos, muzzleCFrame)
	end

	--Corrected distance
	local compassDir, compassLook = GetCompassData()
	local displayDist = targetDist and math.floor(targetDist)
	if targetDist and wpnConfig.RangefinderMax and targetDist >= (wpnConfig.RangefinderMax or 1000) then
		displayDist = "--"
	end

	--Target marking
	local targetLockPos = player:FindFirstChild("Target_Pos") and player.Target_Pos.Value 
	local targetLockObj = player:FindFirstChild("Target_Obj") and player.Target_Obj.Value

	--Reload progress
	local reloadProgress
	local reloading
	if wpnConfig.ReloadTime then
		reloadProgress, reloading = HUDMod.UpdateReload(wpnConfig.ReloadTime, weapon:GetAttribute("internal_ReloadStart"))
	end

	if dtCount>= 1 then dtCount = 0 end
	dtCount += dt

	for each, uiObj in wpnGui:GetDescendants() do
		if table.find(uiElements, uiObj.ClassName)==nil then continue end --Skip invalid elements
		if uiObj.Parent and uiObj.Parent.Visible == false then continue end --Skip elements we cant see

		if uiObj.Name=="Crosshair" then --Follows the cannon's line of sight (with optional drop indicator)
			uiObj.Position = cross1Pos
			uiObj.Visible = cross1Vis and not freeAim
		elseif uiObj.Name=="Crosshair2" then --Follows the camera's center point OR the mouse (depends on settings)
			uiObj.Position = cross2Pos
			uiObj.Visible = cross2Vis and not freeAim
		elseif uiObj.Name=="Sights" then --Crosshair-aligned sights
			uiObj.Position = cross1Pos
			uiObj.Visible = inGunsights
		elseif uiObj.Name=="Sights_Shake" and mouseDelta then --Frame-aligned shaking sights
			uiObj.Position = UDim2.new(uiObj.Position.X.Scale, mouseDelta.X, uiObj.Position.Y.Scale, mouseDelta.Y)
		elseif uiObj.Name=="Sights_Static" then --Frame-aligned sights
			uiObj.Visible = inGunsights
		elseif uiObj.Name=="Sights_Inverse" then --Frame-aligned not-sights
			uiObj.Visible = not inGunsights
		elseif uiObj.Name=="Infrared" then
			uiObj.Visible = weapon:GetAttribute("internal_Infrared") or false
		elseif uiObj.Name=="Countermeasures_Enabled" then
			uiObj.Visible = (vehicle and vehicle:GetAttribute("Vehicle_Countermeasures")) or false
		elseif uiObj.Name=="Countermeasures_Warning" then
			uiObj.Visible = (vehicle and vehicle:HasTag("Dragoon_Target")) or false
		elseif uiObj.Name=="NightVis" then
			uiObj.Visible = weapon:GetAttribute("internal_NightVis") or false
		elseif uiObj.Name=="CompassBand" then
			UpdateCompass(uiObj, dt, compassLook)
		elseif uiObj.Name=="CompassBearing" then
			UpdateCompass2(uiObj, compassDir)
		elseif uiObj.Name=="Reload_Circle" and wpnConfig.ReloadTime then
			uiObj.Visible = reloading

			if reloading then
				local percentNumber = math.clamp(360*reloadProgress,0,360)
				local F1 = uiObj.Frame1.ImageLabel
				local F2 = uiObj.Frame2.ImageLabel
				F1.UIGradient.Rotation = math.clamp(percentNumber,180,360) or 180 - math.clamp(percentNumber,0,180)
				F2.UIGradient.Rotation = math.clamp(percentNumber,0,180) or 180 - math.clamp(percentNumber,180,360)
				F1.UIGradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(0.501, 0.5),NumberSequenceKeypoint.new(1,0.5)})
				F2.UIGradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(0.501,0.5),NumberSequenceKeypoint.new(1,0.5)})
				F1.UIGradient.Color = ColorSequence.new(Color3.new(1,1,1))
				F2.UIGradient.Color = ColorSequence.new(Color3.new(1,1,1))
			end
		elseif uiObj.Name=="AmmoCounter" then --Ammo counter (dual)
			local suffix = uiObj:GetAttribute("Suffix") or ""
			local prefix = uiObj:GetAttribute("Prefix") or ""
			local separa = uiObj:GetAttribute("Separator") or ""

			local gunAmmo = weapon:GetAttribute("clipAmmo")
			local storedAmmo = weapon:GetAttribute("storedAmmo")
			uiObj.Text = prefix..math.floor(gunAmmo)..separa..math.floor(storedAmmo)..suffix
		elseif uiObj.Name=="Firemode" then
			local suffix = uiObj:GetAttribute("Suffix") or ""
			local prefix = uiObj:GetAttribute("Prefix") or ""
			uiObj.Text = prefix..fireModeNames[weapon:GetAttribute("internal_Firemode") + 1]..suffix
		elseif uiObj.Name=="Rangefinder" and (wpnConfig.RangefinderAllowed or wpnConfig.BallisticCalculator) then --Rangefinder (1000 or more)
			local suffix = uiObj:GetAttribute("Suffix") or ""
			local prefix = uiObj:GetAttribute("Prefix") or ""

			if displayDist=="--" then
				uiObj.Text = displayDist
			else
				uiObj.Text = prefix..(math.floor(displayDist/3.5))..suffix --converting from studs to meters
			end
		elseif uiObj.Name=="Zero" and wpnConfig.CanZero then
			local suffix = uiObj:GetAttribute("Suffix") or ""
			local prefix = uiObj:GetAttribute("Prefix") or ""
			local zero = weapon:GetAttribute("internal_Zero") or 0
			uiObj.Text = prefix..math.floor(zero)..suffix
		elseif uiObj.Name=="Angle1" then
			local suffix = uiObj:GetAttribute("Suffix") or ""
			local prefix = uiObj:GetAttribute("Prefix") or ""
			local angle = weapon:GetAttribute("internal_CurAngle") or 0
			uiObj.Text = prefix..tonumber(string.format("%.1f", angle))..suffix
		elseif uiObj.Name=="Angle2" then
			local suffix = uiObj:GetAttribute("Suffix") or ""
			local prefix = uiObj:GetAttribute("Prefix") or ""
			local angle = weapon:GetAttribute("internal_TgtAngle") or 0
			uiObj.Text = prefix..tonumber(string.format("%.1f", angle))..suffix
		elseif uiObj.Name=="FOV_Max" and wpnConfig.GunnerScopeFOV  then
			local suffix = uiObj:GetAttribute("Suffix") or ""
			local prefix = uiObj:GetAttribute("Prefix") or ""
			uiObj.Text = prefix..wpnConfig.GunnerScopeFOV[1]..suffix
		elseif uiObj.Name=="FOV_Min" and wpnConfig.GunnerScopeFOV  then
			local suffix = uiObj:GetAttribute("Suffix") or ""
			local prefix = uiObj:GetAttribute("Prefix") or ""
			uiObj.Text = prefix..wpnConfig.GunnerScopeFOV[2]..suffix
		elseif uiObj.Name=="FOV_Current" and wpnConfig.GunnerScopeFOV  then
			local suffix = uiObj:GetAttribute("Suffix") or ""
			local prefix = uiObj:GetAttribute("Prefix") or ""
			uiObj.Text = prefix..math.floor(playerCam.FieldOfView)..suffix
		elseif uiObj.Name=="Sens_Current" then
			local suffix = uiObj:GetAttribute("Suffix") or ""
			local prefix = uiObj:GetAttribute("Prefix") or ""
			uiObj.Text = prefix..tonumber(string.format("%.1f", userInput.MouseDeltaSensitivity))..suffix
		elseif uiObj.Name=="BDC_VerticalMark" then	
			if inGunsights then
				local dist = uiObj:GetAttribute("BDC_Distance") or 100
				local zero = weapon:GetAttribute("internal_Zero") or 0
				local hide = uiObj:GetAttribute("BDC_HideOnSelect") == nil and true or uiObj:GetAttribute("BDC_HideOnSelect")
				local offset = bcalc.FindBDCOffset(dist, wpnConfig.ShellVelocity*3.5, zero, uiObj:GetAttribute("BDC_IgnoreZeroOffset"), wpnGui)
				uiObj.Position = UDim2.new(uiObj.Position.X.Scale, uiObj.Position.X.Offset, 0.5, offset)
				uiObj.Visible = (hide and (zero ~= dist) or (uiObj:GetAttribute("BDC_Distance") and uiObj:GetAttribute("BDC_Distance") == 0)) or not hide
			else
				local zero = weapon:GetAttribute("internal_Zero") or 0
				local step = wpnConfig.ZeroingStep or 100
				local hide = uiObj:GetAttribute("BDC_HideOnSelect") == nil and true or uiObj:GetAttribute("BDC_HideOnSelect")
				local offset = bcalc.FindBDCOffset(zero, wpnConfig.ShellVelocity*3.5, 0, uiObj:GetAttribute("BDC_IgnoreZeroOffset"), wpnGui)
				uiObj.Position = UDim2.new(uiObj.Position.X.Scale, uiObj.Position.X.Offset, 0.5, offset)
				uiObj.Visible = (hide and zero > 0) or not hide
			end
		elseif uiObj.Name=="ZoomBar" and wpnConfig.GunnerScopeFOV then
			local size = math.map(playerCam.FieldOfView, wpnConfig.GunnerScopeFOV[1], wpnConfig.GunnerScopeFOV[2], 0, 1)
			uiObj.Size = UDim2.new(uiObj.Position.X.Scale, uiObj.Position.X.Offset, size, uiObj.Position.Y.Offset)
		elseif uiObj.Name=="SensBar" then
			local size = math.map(userInput.MouseDeltaSensitivity, 0.005, 0.5, 0, 1)
			uiObj.Size = UDim2.new(uiObj.Position.X.Scale, uiObj.Position.X.Offset, size, uiObj.Position.Y.Offset)
		elseif uiObj.Name=="TankRot_Horizontal" then
			uiObj.Hull.Rotation = math.floor(weapon.Base.TJointBase.Orientation.Z) 
			uiObj.Turret.Rotation = math.floor(weapon.Turret.TJointTop.Orientation.Z)
		elseif uiObj.Name=="RefFrame" then --Arrow
			DrawLine2(uiObj, muzzleCFrame, targetPos)
		elseif uiObj.Name=="Target_PosLabel" then
			local finalPos = targetLockPos or (targetLockObj and targetLockObj:GetPivot().Position)
			if finalPos and finalPos~=Vector3.zero then
				local suffix = uiObj:GetAttribute("Suffix") or ""
				local prefix = uiObj:GetAttribute("Prefix") or ""
				local formatPos = GetFormattedPos(finalPos)
				uiObj.Text = prefix..formatPos..suffix
			else
				local suffix = uiObj:GetAttribute("Suffix") or ""
				local prefix = uiObj:GetAttribute("Prefix") or ""
				uiObj.Text = prefix.."--"..suffix
			end
		elseif uiObj.Name=="Target_DistLabel" and vicPos then
			local finalPos = targetLockPos or (targetLockObj and targetLockObj:GetPivot().Position)
			local finalDist = finalPos and finalPos~=Vector3.zero and (vicPos - finalPos).Magnitude/3.5
			if finalDist and finalDist~=0 then
				local suffix = uiObj:GetAttribute("Suffix") or ""
				local prefix = uiObj:GetAttribute("Prefix") or ""
				uiObj.Text = prefix..string.format("%.1f", finalDist)..suffix
			else
				local prefix = uiObj:GetAttribute("Prefix") or ""
				uiObj.Text = prefix.."--"
			end
		elseif uiObj.Name=="TrajectoryPrediction" and dtCount>0.25 then
			PredictTrajectory(uiObj, wpnConfig, muzzleCFrame)--weapon:GetAttribute("internal_Zero") or 100)
		elseif uiObj.Name=="RefCircle" then
			local angle = weapon:GetAttribute("internal_CurAngle") or 0
			local angle2 = weapon:GetAttribute("internal_CurAngleAz") or 0
			local turretCf = weapon.Base.TJointBase.Direction.WorldCFrame
			
			ReferenceCircle(uiObj, vehicle:GetPivot(), turretCf, angle2, angle)
		elseif uiObj.Name=="NoiseEffect" then --static image effect
			if os.clock() - cache > 1 / 30 then
				cache = os.clock()
				uiObj.Position = UDim2.fromScale(rng:NextNumber(-1, 0), rng:NextNumber(-1, 0))
			end
		end
	end
end

return HUDMod
