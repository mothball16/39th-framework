local module = {}

local debugMode = false

local debris = game:GetService("Debris")
local tweenService = game:GetService("TweenService")
local players = game:GetService("Players")
local Framework = script:FindFirstAncestor("SPH_Framework")
local Access = require(Framework.Access)
local assets = Access.assets
local config = Access.config
local hitFX = require(Framework.Ballistics.HitFX)
local WeaponStatLocator = require(Framework.Weapons.WeaponStatLocator)
local NetworkEvents = require(Framework.Network.NetworkEvents)
local P = NetworkEvents.packets

local sphWorkspace = workspace:WaitForChild("SPH_Workspace")
local bulletContainer = sphWorkspace:WaitForChild("Projectiles")
local cacheContainer = workspace.SPH_Workspace:WaitForChild("Cache")

local pierceMod = require(Framework.Ballistics.PierceMod)
local partCache = require(Framework.Ballistics.PartCache)

local baseBullet = assets:WaitForChild("Projectiles"):WaitForChild("BulletHandlerBase")
local bulletProvider = partCache.new(baseBullet:Clone(),config.maxBullets or 300,cacheContainer)

local fastCast = require(Framework.Ballistics.FastCast)
local bulletBehavior
local rayParams = RaycastParams.new()
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true
rayParams.FilterType = Enum.RaycastFilterType.Exclude

bulletBehavior = fastCast.newBehavior()
bulletBehavior.RaycastParams = rayParams
bulletBehavior.MaxDistance = config.maxBulletDistance
bulletBehavior.AutoIgnoreContainer = true
bulletBehavior.CosmeticBulletContainer = bulletContainer
bulletBehavior.HighFidelityBehavior = fastCast.HighFidelityBehavior.Default
bulletBehavior.CosmeticBulletProvider = bulletProvider
bulletBehavior.CanPierceFunction = pierceMod.CanPierce

local caster = fastCast.new()
fastCast.VisualizeCasts = debugMode

local DEFAULT_SUPPRESSION_DISTANCE = 60
local suppressionOverlapParams = OverlapParams.new()
suppressionOverlapParams.FilterType = Enum.RaycastFilterType.Exclude
suppressionOverlapParams.FilterDescendantsInstances = {}
suppressionOverlapParams.CollisionGroup = "SuppressionTargets"

local player, character
module.Initialize = function(newPlayer)
	player = newPlayer
	character = newPlayer.Character
	rayParams.FilterDescendantsInstances = {character, workspace.CurrentCamera}
	suppressionOverlapParams.FilterDescendantsInstances = {character}
end

local function segmentPointToPartDistance(segStart: Vector3, segDir: Vector3, t: number, part: BasePart): number
	local segPoint = segStart + segDir * t
	local surfacePoint = part:GetClosestPointOnSurface(segPoint)
	return (segPoint - surfacePoint).Magnitude
end

local function closestDistanceSegmentToPart(segStart: Vector3, segDir: Vector3, segLength: number, part: BasePart): number
	local minDist = math.huge

	minDist = math.min(minDist, segmentPointToPartDistance(segStart, segDir, 0, part))
	minDist = math.min(minDist, segmentPointToPartDistance(segStart, segDir, segLength, part))

	-- Closest point on segment to part center, then measure to part surface.
	local distAlongRay = (part.Position - segStart):Dot(segDir)
	local tCenter = math.clamp(distAlongRay, 0, segLength)
	minDist = math.min(minDist, segmentPointToPartDistance(segStart, segDir, tCenter, part))

	return minDist
end

local function ReportSuppressionVictims(cast, lastPoint: Vector3, direction: Vector3, length: number)
	if length <= 0 then
		return
	end

	local segDir = direction.Unit
	local suppressionRadius = cast.UserData.wepStats.suppressionDistance or DEFAULT_SUPPRESSION_DISTANCE
	local seenTargets = cast.UserData.AlreadySuppressedTargets
	if not seenTargets then
		seenTargets = {}
		cast.UserData.AlreadySuppressedTargets = seenTargets
	end

	local midPoint = lastPoint + segDir * (length * 0.5)
	local segmentSize = Vector3.new(
		suppressionRadius * 2,
		suppressionRadius * 2,
		length + suppressionRadius * 2
	)
	local segmentCFrame = CFrame.lookAt(midPoint, midPoint + segDir)
	local nearbyParts = workspace:GetPartBoundsInBox(segmentCFrame, segmentSize, suppressionOverlapParams)

	for _, part in nearbyParts do
		local targetPlayer = players:GetPlayerFromCharacter(part:FindFirstAncestorOfClass("Model"))
		if not targetPlayer 
		or cast.UserData.AlreadySuppressedTargets[targetPlayer.UserId] then
			continue
		end

		-- check if the target is further than minsuppressiondistance from the origin
		if (cast.UserData.Origin - part.Position).Magnitude < config.suppressionMinDistance then
			continue
		end

		
		local closestDistance = closestDistanceSegmentToPart(lastPoint, segDir, length, part)
		if closestDistance > suppressionRadius then
			continue
		end


		local proximityFactor = math.clamp(1 - closestDistance  / suppressionRadius, 0, 1)
		if proximityFactor <= 0 then
			continue
		end

		-- decrease suppression factor exponentially - lower values are more affected
		proximityFactor = math.pow(proximityFactor, 1.7)

		local userId = targetPlayer.UserId

		-- create/update suppression entry in currently suppressed targets
		local existing = cast.UserData.CurrentlySuppressedTargets[userId]
		if not existing then
			existing = {
				target = targetPlayer,
				factor = proximityFactor,
				suppressedTick = tick(),
				dirty = true,
			}
		else
			-- only mark as dirty if the new proximity factor is greater than the existing one
			-- this prevents suppression from being sent in the processing loop
			if proximityFactor > existing.factor then
				existing.factor = proximityFactor
				existing.dirty = true
			end
		end
		cast.UserData.CurrentlySuppressedTargets[userId] = existing
	end

	-- iterate through currently suppressed targets
	-- if not suppressed this time or with a lower suppression, then fire event and mark as suppressed
	for userId, entry in cast.UserData.CurrentlySuppressedTargets do
		if not entry.dirty or tick() - entry.suppressedTick > 0.15 then
			cast.UserData.CurrentlySuppressedTargets[userId] = nil
			cast.UserData.AlreadySuppressedTargets[userId] = true

			-- print(`suppressing {entry.target.Name} with factor {entry.factor}`)
			P.RequestSuppression.send({
				target = entry.target,
				factor = entry.factor,
				level = cast.UserData.wepStats.suppressionLevel,
				limit = cast.UserData.wepStats.suppressionLimit,
			})
		else
			entry.dirty = false
		end

	end
end

local function ResetBullet(bulletPart)
	bulletPart.BulletSmoke.Enabled = false
	bulletPart.PointLight.Enabled = false
	bulletPart.Color = baseBullet.Color
	bulletPart.BeamLong.Color = baseBullet.BeamLong.Color
	bulletPart.BeamLong.Enabled = false
	bulletPart.Transparency = 1
	bulletPart.PointLight.Enabled = false
	bulletPart.PointLight.Color = baseBullet.PointLight.Color
	bulletPart.DistanceEffect.Enabled = false
	bulletPart.DistanceEffect.Dot.ImageColor3 = baseBullet.DistanceEffect.Dot.ImageColor3
	bulletPart.DistanceEffect.Flare.ImageColor3 = bulletPart.DistanceEffect.Flare.ImageColor3
	if bulletPart:FindFirstChild("ProjectileVisual") then
		bulletPart.ProjectileVisual:Destroy()
	end
end

local function PlaySFX(parent, playerFired)
	for _, child in ipairs(parent:GetChildren()) do
		local shouldPlay = false
		if child:IsA("Sound") then
			if child.Name == "Fire" then
				shouldPlay = true
			elseif child.Name == "Echo" and (config.firstPersonEcho or playerFired ~= player) then
				shouldPlay = true
			end
		end

		if shouldPlay then
			if not child.Looped then
				local newFire = child:Clone()
				newFire.PlaybackSpeed += math.random(-10,10) / config.fireSoundVariation
				newFire.Name = newFire.Name.."_Playing"
				newFire.Parent = parent
				newFire:Play()
				debris:AddItem(newFire,newFire.TimeLength == 0 and 5 or newFire.TimeLength)
			else
				child:Play()
			end
		end
	end
end

module.FireBullet = function(rig, bulletOrigin, bulletDirection, bulletVelocity, tool, playerFired, tracerColor, onHitCallback)
	local wepStats = WeaponStatLocator.getWeaponStats(tool)

	bulletBehavior.Acceleration = config.bulletAcceleration

	if not wepStats.bulletDrop then bulletBehavior.Acceleration = Vector3.zero end

	local newBullet = caster:Fire(bulletOrigin,bulletDirection,bulletVelocity,bulletBehavior)
	local newData = {}
	newData.OnHitCallback = onHitCallback
	newData.Player = playerFired
	newData.TracerColor = tracerColor
	newData.Tool = tool
	newData.IgnoreModel = rig
	newData.Visible = false
	newData.Origin = bulletOrigin
	newData.CurrentlySuppressedTargets = {}
	newData.AlreadySuppressedTargets = {}
	newData.wepStats = wepStats

	local bullet = newBullet.RayInfo.CosmeticBulletObject
	if bullet and bullet.Transparency == 0 then
		ResetBullet(bullet)
	end

	local projectileModel = assets.Projectiles:FindFirstChild(wepStats.projectile)
	-- Use projectile model for explosives/grenades regardless of tracers, or for non-tracer bullets
	if projectileModel and (wepStats.explosiveAmmo or not tracerColor) then
		local projectileVisual = projectileModel:Clone()
		projectileVisual.Anchored = false
		projectileVisual.CanCollide = false
		projectileVisual.Name = "ProjectileVisual"
		projectileVisual.Parent = bullet
		newData.Visible = true
	end

	newBullet.UserData = newData

	if wepStats.serverOffset then
		-- Third person recoil animation
		rig.BaseWeld.C0 = wepStats.serverOffset * CFrame.new(0,0,0.17) * CFrame.Angles(math.rad(2),math.rad(math.random(-10,10) / 10),0)
		tweenService:Create(rig.BaseWeld,TweenInfo.new(0.3,Enum.EasingStyle.Back),{C0 = wepStats.serverOffset}):Play()
	end

	if rig:FindFirstChild("Weapon") then
		-- Rocket stuff
		local gunModel = rig.Weapon:FindFirstChildWhichIsA("Model")
		if gunModel and gunModel:FindFirstChild(wepStats.projectile) then
			local projectile = gunModel:FindFirstChild(wepStats.projectile)
			projectile.LocalTransparencyModifier = 1
			for _, child in ipairs(projectile:GetDescendants()) do
				if child:IsA("BasePart") then
					child.LocalTransparencyModifier = 1
				end
			end
		end
	end
end

module.FireFX = function(playerFired:Player, gunModel, firePointName, muzzleChance)
	local base = gunModel:FindFirstChild("Grip") or gunModel:FindFirstChild("Base") or gunModel:FindFirstChild("Main") -- DD_SPH Gunsmith: Added Main as an option for suppressors
	local firePoint = base[firePointName]
	local humanoidRootPart = playerFired.Character:FindFirstChild("HumanoidRootPart")

	-- Sound effects
	PlaySFX(base, playerFired)
	PlaySFX(firePoint, playerFired)

	-- Limit range of other effects
	if humanoidRootPart and player:DistanceFromCharacter(humanoidRootPart.Position) <= config.fireEffectDistance then
		-- Fire effect
		local muzzleChance = math.random(10) <= muzzleChance
		for _, fx in ipairs(firePoint:GetChildren()) do
			if fx:IsA("ParticleEmitter") then
				if fx:GetAttribute("EmitNumber") then -- Using emit attribute
					if string.find(fx.Name,"Flash") then -- Is this a flash particle?
						if muzzleChance then
							fx:Emit(fx:GetAttribute("EmitNumber"))
						end
					else
						fx:Emit(fx:GetAttribute("EmitNumber"))
					end
				elseif fx:FindFirstChild("Particles") then -- Using number value
					local canEmit = false
					if string.find(fx.Name,"Flash") then -- Is this a flash particle?
						if muzzleChance then
							canEmit = true
						end
					else
						canEmit = true
					end
					if canEmit then
						fx:Emit(fx.Particles.Value)
					end
				elseif fx.Name == "Smoke" then -- Default emit amount
					fx:Emit(10)
				elseif fx.Name == "Flash" and muzzleChance then -- Default emit amount
					fx:Emit(5)
				end
			elseif fx:IsA("Light") and muzzleChance then
				fx.Enabled = true
				task.delay(0.01,function() fx.Enabled = false end)
			end
		end

		-- Chamber smoke
		local chamber = firePoint:FindFirstChild("Chamber")
		if chamber then
			for _, fx in ipairs(chamber:GetChildren()) do
				if fx:IsA("ParticleEmitter") then
					if fx:GetAttribute("EmitNumber") then
						fx:Emit(fx:GetAttribute("EmitNumber"))
					elseif fx.Name == "Smoke" then
						fx:Emit(10)
					elseif fx.Name == "Flash" and muzzleChance then
						fx:Emit(5)
					end
				end
			end
		end
	end
end

module.MoveBolt = function(gunModel,wepStats,direction,magAmmo)
	if not gunModel or not gunModel:FindFirstChild("Grip") then return end
	for _, constraint in ipairs(gunModel.Grip:GetChildren()) do
		for _, name in ipairs(wepStats.fireMoveParts) do
			if constraint.Name == name then
				local m6d = constraint
				m6d.C1 = CFrame.new()
				local tInfo = TweenInfo.new(60 / wepStats.fireRate / 2,
					Enum.EasingStyle.Linear,
					Enum.EasingDirection.In,
					0,
					not (magAmmo <= 0 and wepStats.emptyLockBolt))
				local distance
				if typeof(direction) == "CFrame" then
					distance = direction
				else
					distance = CFrame.new(0,0,-direction)
				end
				tweenService:Create(m6d, tInfo, {C1 = distance}):Play()
				break
			end
		end
	end
end


caster.LengthChanged:Connect(function(cast, lastPoint, direction, length, segmentVelocity, cosmeticBulletObject)
	if not cosmeticBulletObject then return end
	if cast.UserData.Player == player and config.suppressionEffects then
		ReportSuppressionVictims(cast, lastPoint, direction, length)
	end

	-- Tracer effects
	if not cast.UserData.Visible and (config.arcadeBullets or cast.UserData.TracerColor)
		and (cast.UserData.Origin - cosmeticBulletObject.Position).Magnitude > config.tracerStartDistance then
		cast.UserData.Visible = true
		local bullet = cosmeticBulletObject
		bullet.Transparency = 0
		bullet.BeamLong.Enabled = true
		bullet.BulletSmoke.Enabled = true
		bullet.PointLight.Enabled = true
		bullet.DistanceEffect.Enabled = true
		if cast.UserData.TracerColor then
			local newColor = cast.UserData.TracerColor
			if config.teamTracers and cast.UserData.Player.Team then
				bullet.Color = cast.UserData.Player.Team.TeamColor.Color
			else
				bullet.Color = newColor
			end
			bullet.BeamLong.Enabled = true
			bullet.BeamLong.Color = ColorSequence.new(newColor)
			bullet.PointLight.Color = newColor
			bullet.BulletSmoke.Enabled = false
			bullet.DistanceEffect.Dot.ImageColor3 = newColor
			bullet.DistanceEffect.Flare.ImageColor3 = newColor
		end
	end

	-- Step bullet to new position
	local bulletLength = cosmeticBulletObject.Size.Z / 2
	local baseCFrame = CFrame.new(lastPoint, lastPoint + direction)
	cosmeticBulletObject.CFrame = baseCFrame * CFrame.new(0, 0, -(length - bulletLength))

	if cosmeticBulletObject:FindFirstChild("ProjectileVisual") then
		cosmeticBulletObject.ProjectileVisual.CFrame = cosmeticBulletObject.CFrame
	end
end)

caster.RayHit:Connect(function(cast, raycastResult, segmentVelocity, cosmeticBulletObject:BasePart)
	
	if cast.UserData.Player ~= player then
		-- this is a replicated bullet, we don't want to process it
		return
	end

	-- report suppression victims for the hit
	if config.suppressionEffects then
		ReportSuppressionVictims(cast, raycastResult.Position, raycastResult.Normal, 1)
	end

	local hitPart = raycastResult.Instance
	hitFX.HitEffect(raycastResult.Position,hitPart,raycastResult.Normal)

	if cast.UserData.OnHitCallback then
		cast.UserData.OnHitCallback(cast.UserData, raycastResult)
	end

	local fakeRayResult = { -- dict instead of RaycastResult for remote
		Position = raycastResult.Position,
		Normal = raycastResult.Normal,
		Instance = raycastResult.Instance,
		Origin = cast.UserData.Origin,
	}

	-- Prepare tool data for server
	local toolData = cast.UserData.Tool
	P.BulletHit.send({
		toolData = toolData,
		rayHit = fakeRayResult,
		bulletCFrame = cosmeticBulletObject.CFrame,
	})

end)

caster.CastTerminating:Connect(function(cast)
	if cast.UserData.Visible then
		local bulletPart = cast.RayInfo.CosmeticBulletObject
		ResetBullet(bulletPart)
	end
	bulletProvider:ReturnPart(cast.RayInfo.CosmeticBulletObject)
end)

return module