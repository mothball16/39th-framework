--[[       
DRAGOON TANK SYSTEM
Ballistic Physics
1.1.1

--]]

--// Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local debris = game:GetService("Debris")
local players = game:GetService("Players")
local BPhys = {}

--// Folders
local assets = replicatedStorage.DTS_Assets
local modules = assets.Modules
local wmodules = assets.Weapons
local amodules = assets.Addons
local projectiles = assets.Projectiles

local pierceMod = require(modules.PierceMod)
local cameraShaker = require(modules.CameraShaker)
local cameraShakeInstance = require(modules.CameraShaker.CameraShakeInstance)
local hitFX = require(modules.HitFX)
local config = require(assets.GlobalSettings)

local sphInstall = replicatedStorage:FindFirstChild("SPH_Assets") --Spearhead compat
local fastCast = require(modules.FastCast)
local bridgeNet
local partCache
local suppression
if sphInstall then 
	bridgeNet = require(sphInstall.Modules.Network.BridgeNet)
	partCache = require(sphInstall.Modules.Ballistics.PartCache)
	--fastCast = require(sphInstall.Modules.Ballistics.FastCast)
	suppression = replicatedStorage:WaitForChild("Suppression",100)
else  
	bridgeNet = require(modules.BridgeNet) 
	partCache = require(modules.PartCache)
	--fastCast = require(modules.FastCast)
	suppression = nil
end

--// Events
local bulletHit = bridgeNet.CreateBridge("BulletHit2")
local bulletRepFocus = bridgeNet.CreateBridge("BulletRepFocus")

local workspaceFolder = game.Workspace.DTS_Workspace
local bulletContainer = workspaceFolder.Temp
local cacheContainer = workspaceFolder.Cache

local player = game.Players.LocalPlayer
local playerCam = game.Workspace.CurrentCamera

local baseBullet = script.Bullet
local bulletProvider = partCache.new(baseBullet:Clone(),config.maxBullets or 300,cacheContainer)

local bulletBehavior
local rayParams = RaycastParams.new()
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true

local aimingParams = RaycastParams.new()
aimingParams.FilterType = Enum.RaycastFilterType.Exclude
aimingParams.IgnoreWater = true

bulletBehavior = fastCast.newBehavior()
bulletBehavior.RaycastParams = rayParams
bulletBehavior.MaxDistance = config.maxBulletDistance
bulletBehavior.AutoIgnoreContainer = true
bulletBehavior.CosmeticBulletContainer = bulletContainer
bulletBehavior.HighFidelityBehavior = fastCast.HighFidelityBehavior.Default
bulletBehavior.CosmeticBulletProvider = bulletProvider
bulletBehavior.CanPierceFunction = pierceMod.CanPierce

local caster = fastCast.new()
fastCast.VisualizeCasts = false

local camShake = cameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
	playerCam.CFrame = playerCam.CFrame * shakeCf
end)
camShake:Start()

--// Functions
local function Reflect(surfaceNormal, bulletNormal)
	return bulletNormal - (2 * bulletNormal:Dot(surfaceNormal) * surfaceNormal)
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
	if bulletPart:FindFirstChild("FakeBullet") then
		bulletPart.FakeBullet:Destroy()
	end
end

local function CastTerminating(cast)
	if cast.UserData.Visible then
		local bulletPart = cast.RayInfo.CosmeticBulletObject
		ResetBullet(bulletPart)
	end
	bulletProvider:ReturnPart(cast.RayInfo.CosmeticBulletObject)
end

local function RayHit(cast, raycastResult:RaycastResult?, segmentVelocity, cosmeticBulletObject:BasePart)
	if not cast.UserData.FakeBullet then
		hitFX.HitEffect(raycastResult.Position, raycastResult.Instance, raycastResult.Normal, raycastResult.Material, cast.UserData.EffectClass)

		local fakeRayResult = { -- Convert the RaycastResult into a generic dictionary, events don't like RaycastResults for some reason
			Position = raycastResult.Position,
			Normal = raycastResult.Normal,
			Instance = raycastResult.Instance,
			Material = raycastResult.Material
		}

		bulletHit:Fire(cast.UserData.WeaponObj,fakeRayResult,cosmeticBulletObject.CFrame)

		-- Suppression effects
		if suppression and config.suppressionEffects and player ~= cast.UserData.Player and not cast.UserData.Cracked then
			suppression:Fire(cast.UserData.SuppressionLevel)
			cast.UserData.Cracked = true
		end
	end
end

local function LengthChanged(cast, segmentOrigin, segmentDirection, length, segmentVelocity, cosmeticBulletObject)
	if not cosmeticBulletObject then return end

	-- Suppression effects
	if suppression and config.suppressionEffects and player ~= cast.UserData.Player and not cast.UserData.Cracked and player:DistanceFromCharacter(cosmeticBulletObject.Position) <= 60 and player:DistanceFromCharacter(cast.UserData.Origin) >= 60 then
		suppression:Fire(cast.UserData.SuppressionLevel)
		cast.UserData.Cracked = true
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
	local baseCFrame = CFrame.new(segmentOrigin, segmentOrigin + segmentDirection)
	cosmeticBulletObject.CFrame = baseCFrame * CFrame.new(0, 0, -(length - bulletLength))

	if cosmeticBulletObject:FindFirstChild("FakeBullet") then
		cosmeticBulletObject.FakeBullet.CFrame = cosmeticBulletObject.CFrame
	end

	-- DTS Fuzes
	local fuzeData:{number} = cast.UserData.Fuzes
	if fuzeData then
		--Get the fuze settings
		local distanceFuze = fuzeData[1]
		local overrideDistance = fuzeData[2] and fuzeData[5]~=0
		local programFuze = overrideDistance and fuzeData[5] 
		local timeFuze = fuzeData[3]
		local proximityFuze = fuzeData[4]
	
		--Get the bullet info
		local distanceCovered = cast.StateInfo.DistanceCovered
		local timeCovered = cast.StateInfo.TotalRuntime

		local distanceTrigger = distanceFuze and not overrideDistance and distanceCovered and distanceCovered>distanceFuze*3.5
		local timeTrigger = timeFuze and timeCovered and timeCovered>timeFuze
		local programTrigger = distanceFuze and programFuze and distanceCovered and distanceCovered>distanceFuze*3.5 and distanceCovered>programFuze
		local proxyTrigger = false --not implemented yet
		
		--Distance fuze
		if distanceTrigger or timeTrigger or programTrigger or proxyTrigger then
			cast.UserData.FuzeTriggered = true
		end
	end
	
	-- DTS Replication focus
	local replicationDistance = config.BulletRepFocus
	local replicationDone = cast.UserData.ReplicationFocusAdded
	if replicationDistance and not replicationDone and cast.StateInfo.DistanceCovered>=replicationDistance then
		cast.UserData.ReplicationFocusAdded = true
		--print("Focus!!", cosmeticBulletObject)
		--bulletRepFocus:Fire(cosmeticBulletObject)
	end

end



function BPhys.FireBullet(vehicle, weaponObj, bulletOrigin, bulletDirection, bulletVelocity, playerFired, tracerColor, fake, grip)
	bulletBehavior.Acceleration = config.bulletAcceleration

	local wepStats = require(weaponObj:FindFirstChildWhichIsA("ModuleScript"))

	local newBullet = caster:Fire(bulletOrigin,bulletDirection,bulletVelocity,bulletBehavior)
	local newData = {}
	newData.Vehicle = vehicle
	newData.Player = playerFired
	newData.WeaponObj = weaponObj
	newData.Muzzle = grip
	newData.TracerColor = tracerColor
	newData.IgnoreModel = vehicle
	newData.FakeBullet = fake
	newData.Visible = false
	newData.Origin = bulletOrigin
	newData.SuppressionLevel = wepStats.ShellSuppression or 1
	newData.EffectClass = wepStats.ShellHitFX or "Hit_Light"
	newData.Fuzes = {wepStats.DistanceFuze, wepStats.ProgrammableFuze, wepStats.TimeFuze, wepStats.ProximityFuze, weaponObj:GetAttribute("internal_Zero")}
	newData.FuzeTriggered = false
	newData.ReplicationFocusAdded = false

	local bullet = newBullet.RayInfo.CosmeticBulletObject
	if bullet and bullet.Transparency == 0 then
		ResetBullet(bullet)
	end

	--Custom model bullet effects
	if wepStats.ShellModel then
		local projectileModel = projectiles:FindFirstChild(wepStats.ShellModel)
		if projectileModel then
			local fakeBullet = projectileModel:Clone()
			fakeBullet.Anchored = false
			fakeBullet.CanCollide = false
			fakeBullet.Name = "FakeBullet"
			fakeBullet.Parent = bullet
			newData.Visible = true

			local bulletCenter = fakeBullet:FindFirstChild("Warhead") or fakeBullet:FindFirstChild("Bullet")
			if bulletCenter then
				local flyby = bulletCenter:FindFirstChild("FlyBy")
				if flyby then flyby:Play() end
			end
		end
	end

	--Simple bullet effects
	local flyby = bullet:FindFirstChild("FlyBy")
	if flyby then flyby:Play() end

	if config.cameraShake and camShake and playerFired==player then
		--Camera shake
		local firemode = weaponObj:GetAttribute("internal_Firemode")
		local cycleTime = (firemode~="Burst" and wepStats.Firerate) or (firemode=="Burst" and wepStats.BurstFirerate)
		local c = cameraShakeInstance.new(wepStats.CameraShake or 0.5, 4, 0, 60/cycleTime) --magnitude, roughness, fadeInTime, fadeOutTime
		c.PositionInfluence = Vector3.new(0.25, 0.25, 0.25)
		c.RotationInfluence = Vector3.new(2, 1, 1)
		camShake:Shake(c)
	end
	newBullet.UserData = newData
	
end

function BPhys.FireFX(playerFired:Player, grip, muzzleChance)
	local humanoidRootPart = playerFired.Character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and player:DistanceFromCharacter(humanoidRootPart.Position) <= config.fireEffectDistance then

		-- Fire sound
		for _, child in grip:GetChildren() do
			if child:IsA("Sound") and (child.Name == "Fire" or (child.Name == "Echo" and (config.firstPersonEcho or playerFired ~= player))) then
				if not child.Looped then
					local newFire = child:Clone()
					newFire.PlaybackSpeed += math.random(-10,10) / config.fireSoundVariation
					newFire.Name = newFire.Name.."_Playing"
					newFire.Parent = grip.Muzzle
					newFire:Play()
					debris:AddItem(newFire,newFire.TimeLength == 0 and 5 or newFire.TimeLength)
				else
					child:Play()
				end
			end
		end

		-- Fire effect
		local muzzleChance = math.random(10) <= muzzleChance
		for _, fx in grip.Muzzle:GetChildren() do
			if fx:IsA("ParticleEmitter") then
				if fx:FindFirstChild("Particles") then
					local canEmit = false
					if string.find(fx.Name,"Flash") then
						if muzzleChance then
							canEmit = true
						end
					else
						canEmit = true
					end
					if canEmit then
						fx:Emit(fx.Particles.Value)
					end
				elseif fx.Name == "Smoke" then
					fx:Emit(10)
				elseif fx.Name == "Flash" and muzzleChance then
					fx:Emit(5)
				end
			elseif fx:IsA("Light") and muzzleChance then
				fx.Enabled = true
				task.delay(0.01,function() fx.Enabled = false end)
			end
		end

		-- Other effects
		local chamber:Attachment = grip:FindFirstChild("Chamber")
		if chamber then
			local casings:ParticleEmitter = chamber:FindFirstChild("Casings")
			if casings then
				casings:Emit(1)
			end
		end
	end
end


--// Connections
caster.LengthChanged:Connect(LengthChanged)
caster.RayHit:Connect(RayHit)
caster.CastTerminating:Connect(CastTerminating)

return BPhys
