local debugMode = false

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local debris = game:GetService("Debris")
local httpService = game:GetService("HttpService")
local assets = replicatedStorage.SPH_Assets
local animations = assets.Animations
local modules = assets.Modules

local player = players.LocalPlayer

local config = require(assets.GameConfig)
local warnPrefix = "【 SPEARHEAD 】 "
print(warnPrefix.."Loading Client "..config.version)
local hitFX = require(modules.HitFX)
local shellEjection = require(modules.ShellEjection)
local bulletHandler = require(modules.BulletHandler)

local bridgeNet = require(replicatedStorage.SPH_Assets.Modules.BridgeNet)
local bodyAnimCommand = bridgeNet.CreateBridge("BodyAnimCommand")
local repFire = bridgeNet.CreateBridge("ReplicateFire")
local repSound = bridgeNet.CreateBridge("ReplicateSound")
local repHit = bridgeNet.CreateBridge("ReplicateHit")
local repBolt = bridgeNet.CreateBridge("ReplicateBolt")
local repCharSound = bridgeNet.CreateBridge("ReplicateCharacterSound")
local repToggleAttachment = bridgeNet.CreateBridge("ReplicateToggleAttachment")
local repMagGrab = bridgeNet.CreateBridge("ReplicateMagGrab")
local repLean = bridgeNet.CreateBridge("ReplicateLean")

-- DD_SPH Gunsmith
local gunsmith = require(modules.Gunsmith)
local gunsmithHandler = require(replicatedStorage.DD_GunsmithHandler)
local InitiateGunsmith = bridgeNet.CreateBridge("InitiateGunsmith")

local animLoadStorage = {}
local lasers = {}

local function AddRig(rig:Model, name:string)
	local newData = {
		animator = rig.AnimationController.Animator,
		LoadedAnimations = {}
	}
	animLoadStorage[name] = newData
end

local function FireBullet(player:Player, firePoint:CFrame, tracer:boolean)
	local tool = player.Character:FindFirstChildWhichIsA("Tool")
	if tool and tool:FindFirstChild("SPH_Weapon") then
		local rig = player.Character.WeaponRig
		local gunModel = rig.Weapon:FindFirstChildWhichIsA("Model")
		local wepStats = require(tool.SPH_Weapon.WeaponStats)
		local muzzle = gunModel.Grip.Muzzle
		local gunAmmo = tool.Ammo


		-- DD_SPH Gunsmith
		local plrAttStats
		if wepStats.Attachments then
			plrAttStats = gunsmith.getAttStats(wepStats.Attachments)
		end

		-- Fire effects
		--bulletHandler.FireFX(player,gunModel,"Muzzle",wepStats.muzzleChance)
		local muCh = wepStats.muzzleChance -- DD_SPH Gunsmith: Adjusting muzzle chance
		local fxTarget = gunModel-- DD_SPH gunsmith: supporting different muzzle devices
		if plrAttStats then
			if plrAttStats.muzzleChance then
				muCh = plrAttStats.muzzleChance
			end
			if plrAttStats.newMuzzleDevice then
				fxTarget = gunModel[plrAttStats.newMuzzleDevice]
			end
		end
		bulletHandler.FireFX(player,fxTarget,"Muzzle",muCh)
		-- </DD_SPH>


		-- Fire bullet
		local muzzle = gunModel.Grip.Muzzle
		local bulletOrigin = muzzle.WorldCFrame.Position
		local bulletDirection = muzzle.WorldCFrame.LookVector
		--local bulletVelocity = (bulletDirection * wepStats.muzzleVelocity * 3.5) -- 1 Meter = ~3.5 Studs (According to the dev forum)

		-- DD_SPH Gunsmith: Muzzle Velocity alteration based on plrAttStats
		local muVe = wepStats.muzzleVelocity
		if plrAttStats then
			if plrAttStats.muzzleVelocityReplace then -- Replace the muzzle velocity with a new one (swapping calibers)
				muVe = plrAttStats.muzzleVelocityReplace
			end
			if plrAttStats.muzzleVelocity then -- Increase or decrease muzzle velocity by a certain percentage (barrel length, improved rifling etc.)
				muVe *= plrAttStats.muzzleVelocity
			end
		end
		local bulletVelocity = (bulletDirection * muVe * 3.5) -- 1 Meter = ~3.5 Studs (According to the dev forum)
		-- </DD_SPH Gunsmith

		local tracerColor = nil
		--if wepStats.tracers and gunAmmo.MagAmmo.Value % wepStats.tracerTiming == 0 then
		--	tracerColor = wepStats.tracerColor
		--end
		-- DD_SPH Gunsmith: Adjusting tracer timing with gunsmith
		local TrTi = wepStats.tracerTiming
		local possibleTracerColor = wepStats.tracerColor
		if plrAttStats then
			if plrAttStats.tracerTiming then
				TrTi = plrAttStats.tracerTiming
			end
			if plrAttStats.tracerColor then
				possibleTracerColor = plrAttStats.tracerColor
			end
			if wepStats.tracers and gunAmmo.MagAmmo.Value % TrTi == 0 then
				tracerColor = possibleTracerColor
			end
		end
		-- </DD_SPH>

		if tracerColor == "Random" then -- DD_SPH: Rainbow Tracers
			tracerColor = Color3.fromRGB(math.random(0,255),math.random(0,255),math.random(0,255))
		end -- </DD_SPH>

		bulletHandler.FireBullet(rig,bulletOrigin,bulletDirection,bulletVelocity,tool,player,tracerColor,true)

		-- Shell ejection
		if wepStats.fireMode ~= "Manual" and wepStats.shellEject then
			shellEjection.ejectShell(player,tool,gunModel)
		end
	end 
end

-- Update character stuff
bodyAnimCommand:Connect(function(character:Model, angle)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 or (not character:FindFirstChild("Torso") and not character:FindFirstChild("UpperTorso")) then return end

	-- Head movement
	local avatarType = character.Humanoid.RigType
	local joint
	if avatarType == Enum.HumanoidRigType.R6 then
		joint = character.Torso.Neck
	else
		joint = character.Head.Neck -- DD_SPH: formerly UpperTorso (this was incorrect)
	end

	local moveSpeed = config.replicatedHeadRotationSpeed

	tweenService:Create(joint,TweenInfo.new(moveSpeed,Enum.EasingStyle.Quad),{C1 = angle}):Play()
end)

repLean:Connect(function(character:Model, leanDirection)
	if not character:FindFirstChild("HumanoidRootPart") then return end
	local avatarType = character.Humanoid.RigType

	-- Update leaning
	local targetCFrame -- = CFrame.new(-leanDirection / 2,0,0) * CFrame.Angles(math.rad(90),math.rad(180) + math.rad(17 * leanDirection),0)
	local baseJoint -- = character.HumanoidRootPart:FindFirstChild("RootJoint")

	if avatarType == Enum.HumanoidRigType.R6 then -- DD_SPH: rigCheck for leaning
		baseJoint = character.HumanoidRootPart:FindFirstChild("RootJoint")
		targetCFrame = CFrame.new(-leanDirection / 2,0,0) * CFrame.Angles(math.rad(90),math.rad(180) + math.rad(17 * leanDirection),0)
	else -- DD_SPH time
		baseJoint = character.UpperTorso:FindFirstChild("Waist")
		targetCFrame = CFrame.new(baseJoint.C1.Position.X,baseJoint.C1.Position.Y,baseJoint.C1.Position.Z) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0) + math.rad(17 * leanDirection))
	end
	if baseJoint then
		tweenService:Create(baseJoint,TweenInfo.new(0.5),{C1 = targetCFrame}):Play()
	end
end)

repFire:Connect(FireBullet)

repSound:Connect(function(player:Player, soundToPlay:Sound, dupeSound:boolean)
	if not soundToPlay then return end

	if not dupeSound then
		soundToPlay:Play()
	else
		if not player.Character:FindFirstChild("Torso") or not player.Character:FindFirstChild("UpperTorso") then return end
		local newSound = soundToPlay:Clone()
		if not soundToPlay.Parent or not soundToPlay.Parent:IsA("BasePart") then
			newSound.Parent = player.Character.HumanoidRootPart
		end
		newSound.Parent = soundToPlay.Parent
		newSound:Play()
		--print(newSound.Name)
		local soundLength = newSound.TimeLength
		if soundLength < 1 then soundLength = 1 end
		debris:AddItem(newSound,soundLength)
	end
end)

repHit:Connect(function(tool:Tool, raycastResult:RaycastResult)
	local hitPart = raycastResult.Instance
	local bulletStats = require(tool.SPH_Weapon.WeaponStats)
	if raycastResult.Instance and bulletStats.projectile == "Bullet" then
		hitFX.HitEffect(raycastResult.Position,hitPart,raycastResult.Normal)
	end
end)

repBolt:Connect(function(player, direction, magAmmo)
	local gunModel = player.Character.WeaponRig.Weapon:FindFirstChildWhichIsA("Model")
	local wepStats = require(player.Character:FindFirstChildWhichIsA("Tool").SPH_Weapon.WeaponStats)
	local boltData = {
		fireMoveParts = wepStats.fireMoveParts;
		fireRate = wepStats.fireRate;
		emptyLockBolt = wepStats.emptyLockBolt;
	}

	-- DD_SPH Gunsmith
	local plrAttStats
	if wepStats.Attachments then
		plrAttStats = gunsmith.getAttStats(wepStats.Attachments)
	end
	if plrAttStats and plrAttStats.fireRate then -- DD_SPH Gunsmith
		boltData.fireRate *= plrAttStats.fireRate
	end -- </DD_SPH>
	bulletHandler.MoveBolt(gunModel,boltData,direction,magAmmo)
end)

repCharSound:Connect(function(player, soundType)
	local humanoidRootPart = player.Character:WaitForChild("HumanoidRootPart")
	if humanoidRootPart then
		local soundList = assets.Sounds[soundType]:GetChildren()
		local newSound = soundList[math.random(#soundList)]:Clone()
		newSound.Parent = humanoidRootPart
		newSound:Play()
		debris:AddItem(newSound,newSound.TimeLength)
	end
end)

repToggleAttachment:Connect(function(attachment,toggle,character)
	if attachment.Name == "Flashlight" then
		attachment:FindFirstChildWhichIsA("Light").Enabled = toggle
	elseif attachment.Name == "Laser" then
		if toggle then -- Make new laser object
			local laserDot = Instance.new("Attachment",workspace.Terrain)
			laserDot.Name = "ReplicatedLaser"

			local laserDotUI = assets.HUD.LaserDotUI:Clone()
			laserDotUI.Enabled = true
			laserDotUI.Dot.ImageColor3 = attachment.Color.Value
			laserDotUI.Parent = laserDot

			local newLaser = {}
			newLaser.laserDot = laserDot
			newLaser.attachment = attachment
			newLaser.ignoreModel = character
			table.insert(lasers,newLaser)
		else
			for i, laserObject in ipairs(lasers) do
				if laserObject.attachment == attachment then
					laserObject.laserDot:Destroy()
					table.remove(lasers,i)
					break
				end
			end
		end
	elseif attachment.Name == "Bipod" then
		print(attachment.Parent.Parent)
		print(toggle)
		for i, bipObject in pairs(attachment.Parent.Parent:GetChildren()) do
			if bipObject.Name == "Bipod_On" then
				if toggle then
					bipObject.Transparency = 0
				else
					bipObject.Transparency = 1
				end
			end
			if bipObject.Name == "Bipod_Off" then
				if toggle then
					bipObject.Transparency = 1
				else
					bipObject.Transparency = 0
				end
			end
		end
	end
end)

runService.RenderStepped:Connect(function()
	for i, laserObject in ipairs(lasers) do
		local laserPoint = laserObject.attachment
		if laserPoint and laserPoint.Parent then
			local laserRayParams = RaycastParams.new()
			laserRayParams.FilterType = Enum.RaycastFilterType.Exclude
			laserRayParams.FilterDescendantsInstances = {laserObject.ignoreModel}
			local laserDotPoint = laserObject.laserDot
			local rayResult = workspace:Raycast(laserPoint.WorldPosition, laserPoint.WorldCFrame.LookVector * 600, laserRayParams)
			if rayResult then
				laserObject.laserDot.LaserDotUI.Enabled = true
				laserDotPoint.WorldPosition = rayResult.Position
			else
				laserObject.laserDot.LaserDotUI.Enabled = false
			end
		else
			laserObject.laserDot:Destroy()
			table.remove(lasers,i)
		end
	end
end)

repMagGrab:Connect(function(magPart)
	if magPart then
		magPart.LocalTransparencyModifier = 0
		for _, part in ipairs(magPart:GetDescendants()) do
			if part:IsA("BasePart") then part.LocalTransparencyModifier = 0 end
		end
	end
end)

-- DD_SPH Gunsmith
InitiateGunsmith:Connect(function(weaponTool, weaponModel)
	gunsmithHandler.Init(weaponTool, weaponModel)
end)

print(warnPrefix.."Main Client loaded successfully!")