--[[       
DRAGOON TANK SYSTEM
Server Script
1.2.0
--]]

--// Services
local players = game:GetService("Players")
local debris = game:GetService("Debris")
local collection = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")

--// Folders
local assets = replicatedStorage.DTS_Assets
local events = assets.Events
local modules = assets.Modules
local wmodules = assets.Weapons
local amodules = assets.Addons
local fx = assets.FX
local projectiles = assets.Projectiles

local sphInstall = replicatedStorage:FindFirstChild("SPH_Assets") --Spearhead compat
local bridgeNet
if sphInstall then 
	bridgeNet = require(sphInstall.Modules.BridgeNet)
else  
	bridgeNet = require(modules.BridgeNet) 
end

local validAttributes = require(script.AttributeList)
local notifMod = require(replicatedStorage.INTERACT_Assets.Modules.NotifModule) --Interact system shared module
local atmod = require(modules.Antitank)
local explosionMod = require(modules.ExplosionFX)
local craterMod = require(modules.CraterMod)
local setup = require(modules.VehicleSetup)
local config = require(assets.GlobalSettings)
warn(config.prefix.." Loading Server "..config.version)

local workspaceFolder = game.Workspace.DTS_Workspace
local tempFolder = workspaceFolder.Temp
local cacheFolder = workspaceFolder.Cache

--// Collision groups
local physicsService = game:GetService("PhysicsService")
physicsService:RegisterCollisionGroup("VehicleBody")
physicsService:RegisterCollisionGroup("VehicleWheels")
physicsService:RegisterCollisionGroup("VehicleTurret")
physicsService:RegisterCollisionGroup("VehicleGun")
physicsService:CollisionGroupSetCollidable("VehicleBody","VehicleTurret",false)
physicsService:CollisionGroupSetCollidable("VehicleBody","VehicleGun",false)
physicsService:CollisionGroupSetCollidable("VehicleTurret","VehicleGun",false)
physicsService:CollisionGroupSetCollidable("VehicleBody","VehicleWheels",false)
physicsService:CollisionGroupSetCollidable("VehicleTurret","VehicleWheels",false)
physicsService:CollisionGroupSetCollidable("VehicleGun","VehicleWheels",false)
physicsService:CollisionGroupSetCollidable("Default", "VehicleTurret", false)
physicsService:CollisionGroupSetCollidable("Default", "VehicleWheels", true)
physicsService:CollisionGroupSetCollidable("Default", "VehicleBody", true)

--// Events
local rotateAssembly = bridgeNet.CreateBridge("rotateAssembly") -- Client > Server 
local rotateAssembly2 = bridgeNet.CreateBridge("rotateAssembly2") -- Server > Client
local exitTank = bridgeNet.CreateBridge("exitTank") -- Client > Server 
local attSet = bridgeNet.CreateBridge("attributeSet") -- Client > Server 
local getOwner = bridgeNet.CreateBridge("getOwner") -- Client > Server 
local bulletHit = bridgeNet.CreateBridge("BulletHit2") -- Server > Client
local bulletRepFocus = bridgeNet.CreateBridge("BulletRepFocus") -- Client > Server
local repFire = bridgeNet.CreateBridge("ReplicateFire2")
local repHit = bridgeNet.CreateBridge("ReplicateHit2") -- Server > Client
local playerFire = bridgeNet.CreateBridge("PlayerFire2")
local playerReload = bridgeNet.CreateBridge("PlayerReload2")
local vehicleReplenish = bridgeNet.CreateBridge("VehicleReplenish")
local gunEvent = bridgeNet.CreateBridge("WeaponEvent")
local modEvent = bridgeNet.CreateBridge("AddonEvent")
local forceReload = events.ReloadEvent

local explosionOverlapParams = OverlapParams.new()
explosionOverlapParams.MaxParts = 500
--explosionOverlapParams.RespectCanCollide = true

local explosionRayParams = RaycastParams.new()
explosionRayParams.IgnoreWater = true
--explosionRayParams.RespectCanCollide = true

local replicationFocus = {} --[player] = {}

--// Misc functions
local function TeamKillCheck(player1:Player, player2:Player)
	-- Teamkill stuff
	if not config.FriendlyFire and not player1.Neutral and not player2.Neutral then
		if player1.Team == player2.Team then
			return false
		end
	end
	return true
end

local function ParentCheckIII(Part:BasePart, ParentTag:string, Times:number)
	local tries = 0
	Times = Times or 6
	local currentPart = Part
	while currentPart and tries < Times do
		if currentPart:HasTag(ParentTag) then return currentPart end
		currentPart = currentPart.Parent
		tries += 1
	end
	return nil
end

local function hideModel(model, transparency)
	if model:IsA("BasePart") then
		model.Transparency = transparency
	end

	local modelParts = model:GetChildren()
	for _, part in pairs(modelParts) do
		if part:IsA("BasePart") then
			part.Transparency = transparency
		elseif part:IsA("Model") or part:IsA("Folder") then
			hideModel(part, transparency)	
		end
	end
end

--// Functions
local function RotateAssemblyHinges(Player, TurretHinge, GunHinge, Rotation, Elevation, TurretSpeed, GunSpeed)
	if not config.DirectTurretReplication and config.UseWeldReplication then
		if TurretHinge then TurretHinge.C1 = Rotation end
		if GunHinge then GunHinge.C1 = Elevation end
	elseif not config.DirectTurretReplication and not config.UseWeldReplication then
		if TurretHinge then
			TurretHinge.AngularSpeed = TurretSpeed
			TurretHinge.TargetAngle = Rotation
		end
		if GunHinge then
			GunHinge.AngularSpeed = GunSpeed
			GunHinge.TargetAngle = Elevation
		end
	elseif config.DirectTurretReplication and config.UseWeldReplication then
		if false then
			if TurretHinge then TurretHinge.C1 = Rotation end
			if GunHinge then GunHinge.C1 = Elevation end
		end
		rotateAssembly2:FireToAllExcept(Player, TurretHinge, GunHinge, Rotation, Elevation, TurretSpeed, GunSpeed)
	elseif config.DirectTurretReplication and not config.UseWeldReplication then
		rotateAssembly2:FireToAllExcept(Player, TurretHinge, GunHinge, Rotation, Elevation, TurretSpeed, GunSpeed)
	end
end

local function GetOwner(player: Player, Part: BasePart)
	if not Part then print("no part :(") return end
	getOwner:FireTo(player, Part:GetNetworkOwner(), Part:GetNetworkOwnershipAuto())
end

local function VehicleReplenish(player: Player, replenishStats:Tool?, Vehicle, Action)
	if Vehicle:GetAttribute("Vehicle_HP")<=0 or Vehicle:HasTag("Dragoon_Destroyed") then return end
	if player and player.Character:FindFirstChildWhichIsA("Humanoid").Sit then return end
	local replenished = false
	local ammoDepleted = false
	local notifMessage = nil

	local function DeleteTool()
		if replenishStats and replenishStats:IsA("Tool") and player.Character and replenishStats:IsDescendantOf(player.Character) then
			replenishStats:Destroy()
		end
	end

	if Action == "Repair" then -- repair the vehicle
		local newHp = 0

		if replenishStats:GetAttribute("Uses_Left")>0 or replenishStats:GetAttribute("Uses_Infinite") then
			local healing = replenishStats:GetAttribute("Health_Increment")
			local vehicleHP = Vehicle:GetAttribute("Vehicle_HP")
			local vehicleMax = Vehicle:GetAttribute("Vehicle_MaxHP")
			if not vehicleHP or not vehicleMax or vehicleHP>=vehicleMax then return end

			replenishStats:SetAttribute("Uses_Left", replenishStats:GetAttribute("Uses_Left")-1)
			newHp = math.clamp(vehicleHP+healing, 0, vehicleMax)
			Vehicle:SetAttribute("Vehicle_HP", newHp)
			replenished = true
		end

		if replenished then 
			local hpRatio = Vehicle:GetAttribute("Vehicle_HP") / Vehicle:GetAttribute("Vehicle_MaxHP")
			notifMessage = [[<font color="#8aff4b"> ]].."["..Vehicle:GetAttribute("Vehicle_Name").."] "..[[</font>]].."has been healed!"..[[<font color="#ee4545"> ]].." [Current HP: "..math.ceil(hpRatio*100).."%]  "..[[</font>]]
		end

	elseif Action == "Refuel" then -- fill 'er up!
		local newFuel = 0

		if replenishStats:GetAttribute("Fuel_Left")>0 or replenishStats:GetAttribute("Fuel_Infinite") then
			local fuelCurrent = Vehicle:GetAttribute("Fuel_Current")
			local fuelMax = Vehicle:GetAttribute("Fuel_Max")
			if not fuelCurrent or not fuelMax or fuelCurrent >= fuelMax then return end

			local vicFuelType = Vehicle:GetAttribute("Fuel_Type")
			local pumpFuelType = replenishStats:GetAttribute("Fuel_Type")
			if (vicFuelType~=nil and vicFuelType~=pumpFuelType) or (vicFuelType==nil and not (pumpFuelType=="Standard" or pumpFuelType==nil)) then return end

			local refuelStep = replenishStats:GetAttribute("Fuel_Increment")
			local refuelStored = replenishStats:GetAttribute("Fuel_Left")

			if refuelStored<refuelStep then refuelStep=refuelStored end

			newFuel = math.clamp(fuelCurrent+refuelStep, 0, fuelMax)
			Vehicle:SetAttribute("Fuel_Current", newFuel)
			if replenishStats:GetAttribute("Fuel_Infinite")~=true then
				replenishStats:SetAttribute("Fuel_Left", refuelStored-refuelStep)
			end
			replenished = true
		end

		if replenished then 
			local fuelRatio = Vehicle:GetAttribute("Fuel_Current") / Vehicle:GetAttribute("Fuel_Max")
			notifMessage = [[<font color="#8aff4b"> ]].."["..Vehicle:GetAttribute("Vehicle_Name").."] "..[[</font>]].."has been refueled!"..[[<font color="#ff8f63"> ]].." [Current fuel: "..math.ceil(fuelRatio*100).."%] "..[[</font>]]
		end

	elseif Action == "Reload" then -- restock the vehicle's ammo
		local weapons = Vehicle:FindFirstChild("Weapons")
		local replenishType = replenishStats:GetAttribute("Weapon_Name")

		if not weapons then return end

		weapons = weapons:GetChildren()
		for each, weapon in ipairs(weapons) do
			local weaponName = weapon:GetAttribute("Weapon_Name") 
			local weaponShell = weapon:GetAttribute("Weapon_ShellType") 

			if (weaponName and weaponName == replenishType) or (weaponShell and weaponShell==replenishType) or replenishStats:GetAttribute("Ammo_Universal")==true then
				local ammoStored = weapon:GetAttribute("storedAmmo")
				local ammoMax = weapon:GetAttribute("maxAmmo")
				if ammoStored >= ammoMax or ammoDepleted then continue end

				local rearmStep = replenishStats:GetAttribute("Ammo_Increment")
				local rearmStored = replenishStats:GetAttribute("Ammo_Left")

				if rearmStored<rearmStep then rearmStep=rearmStored end

				weapon:SetAttribute("storedAmmo", math.clamp(ammoStored+rearmStep, 0, ammoMax))
				if replenishStats:GetAttribute("Ammo_Infinite")~=true then
					replenishStats:SetAttribute("Ammo_Left", rearmStored-rearmStep)
				end
				rearmStored = replenishStats:GetAttribute("Ammo_Left")
				if rearmStored <= 0 then ammoDepleted=true end

				replenished = true
			end
		end

		if replenished then
			notifMessage = [[<font color="#8aff4b"> ]].."["..Vehicle:GetAttribute("Vehicle_Name").."] "..[[</font>]].."has been rearmed!"
		end
	end

	if replenished then
		if replenishStats and replenishStats:IsA("Tool") and replenishStats.Handle:FindFirstChild("Sound") then
			replenishStats.Handle.Sound:Play()
		end
		if notifMessage then
			notifMod.Notificate(player, false, "LowerMid", 3, notifMessage)
		end

		if ammoDepleted then
			DeleteTool()
		end
	end
end

local function PlayerReload(player:Player, vehicle:Model, weapon:Model, grip:BasePart)
	if typeof(grip) == `table` then
		warn(`DTS_Server: {player} sent grip on PlayerReload as a table`)
		return
	end

	if not vehicle or not weapon then warn(config.prefix.." PlayerReload Canceled: No vehicle was found.") return end
	local wepStats = require(weapon:FindFirstChildWhichIsA("ModuleScript"))
	local gunAmmo = weapon:GetAttribute("storedAmmo")
	local magAmmo = weapon:GetAttribute("clipAmmo")
	local reloading = weapon:GetAttribute("internal_Reloading")
	local chamber = weapon:GetAttribute("internal_Chambered")

	local magMax = wepStats.ClipSize
	local magMissing = magMax-magAmmo

	if not reloading then
		if gunAmmo<=0 then
			return
		elseif gunAmmo>=magMissing then
			weapon:SetAttribute("internal_Reloading", true)
			weapon:SetAttribute("internal_Chambered", false) 
			if wepStats.ShellAmmo~=nil then hideModel(wepStats.ShellAmmo, 1) end

			local reloadSound:Sound = grip:FindFirstChild("Reload")
			if reloadSound and config.reloadSoundLast then
				task.wait(wepStats.ReloadTime-reloadSound.TimeLength)
				reloadSound:Play()
				task.wait(reloadSound.TimeLength)
			elseif reloadSound then
				reloadSound:Play()
				task.wait(wepStats.ReloadTime) 
			else
				task.wait(wepStats.ReloadTime) 
			end

			weapon:SetAttribute("clipAmmo", magAmmo+magMissing)
			weapon:SetAttribute("storedAmmo", gunAmmo-magMissing)
			weapon:SetAttribute("internal_Reloading", false)
			weapon:SetAttribute("internal_Chambered", true) 
			if wepStats.ShellAmmo~=nil then hideModel(wepStats.ShellAmmo, 0) end
		else
			weapon:SetAttribute("internal_Reloading", true)
			weapon:SetAttribute("internal_Chambered", false) 
			if wepStats.ShellAmmo~=nil then hideModel(wepStats.ShellAmmo, 1) end

			local reloadSound:Sound = grip:FindFirstChild("Reload")
			if reloadSound and config.reloadSoundLast then
				task.wait(wepStats.ReloadTime-reloadSound.TimeLength)
				reloadSound:Play()
				task.wait(reloadSound.TimeLength)
			elseif reloadSound then
				reloadSound:Play()
				task.wait(wepStats.ReloadTime) 
			else
				task.wait(wepStats.ReloadTime) 
			end

			weapon:SetAttribute("clipAmmo", gunAmmo)
			weapon:SetAttribute("storedAmmo", 0)
			weapon:SetAttribute("internal_Reloading", false)
			weapon:SetAttribute("internal_Chambered", true) 
			if wepStats.ShellAmmo~=nil then hideModel(wepStats.ShellAmmo, 0) end
		end

	end
end

local function PlayerFire(player:Player, firePoint:CFrame, vehicle:Model, weapon:Model, grip:BasePart) 
	if not vehicle or not weapon then 
		warn(config.prefix.." PlayerFire Canceled: No vehicle was found.") 
		return 
	end

	local wepStats = require(weapon:FindFirstChildWhichIsA("ModuleScript"))
	local magAmmo = weapon:GetAttribute("clipAmmo")
	local reloading = weapon:GetAttribute("internal_Reloading")
	local chamber = weapon:GetAttribute("internal_Chambered")

	local point = player.Character.HumanoidRootPart.Position
	local dist = config.fireEffectDistance --plr, firePoint, vehicle, weapon, gun
	repFire:FireAllInRangeExcept(player,point,dist,player,firePoint, vehicle, weapon, grip)

	--Firing effects
	if wepStats.RecoilForce then
		local tempAtt = Instance.new("Attachment")
		tempAtt.Parent = grip
		tempAtt.CFrame = grip.Muzzle.CFrame
		local force = Instance.new("VectorForce")
		force.Parent = tempAtt
		force.Attachment0 = tempAtt
		force.Force = Vector3.new(0,0, wepStats.RecoilForce)
		debris:AddItem(tempAtt,0.1)
	end

	-- Proceed with firing logic
	if chamber and not reloading then
		weapon:SetAttribute("internal_Chambered", false)
		if magAmmo > 0 then
			weapon:SetAttribute("clipAmmo", magAmmo-1)
			magAmmo = weapon:GetAttribute("clipAmmo")

			if magAmmo <= 0 then --fired the last bullet, now we have to reload
				PlayerReload(player, vehicle, weapon, grip)
			else
				weapon:SetAttribute("internal_Chambered", true)
			end
		end
	end
end

local function BulletRepFocus(player:Player, bulletPart)
	print(player, bulletPart)
	if not player or not config.BulletRepFocus or not bulletPart or not bulletPart:IsDescendantOf(tempFolder) then return end

	local replicationFoci = replicationFocus[player]
	if replicationFoci and #replicationFoci >= 2 then warn("DTS_Server: Player "..player.Name.." is already over the limit of bullet replication foci!") return end

	print("DTS_Server: Added replication focus for "..player.Name)
	player:AddReplicationFocus(bulletPart)
	table.insert(replicationFocus[player])
end

local function BulletHit(player:Player, weapon, raycastResult:RaycastResult, bulletCFrame:CFrame)
	if not weapon then return end
	local wepStats = require(weapon:FindFirstChildWhichIsA("ModuleScript"))

	local pen = math.abs(math.random(wepStats.DefaultPen[1], wepStats.DefaultPen[2]))
	local dmg = math.abs(math.random(wepStats.DefaultDamage[1], wepStats.DefaultDamage[2]))
	local plrDmg = math.random(wepStats.DefaultPlrDamage[1], wepStats.DefaultPlrDamage[2])
	local knockback = (config.useBulletForce and Vector3.new(0,0, -wepStats.ShellForce or 0)) or nil

	local humanoidsHit = {}
	local vehiclesHit = {}
	local propsHit = {}

	-- Replicate hit effect to other clients
	local position = raycastResult.Position
	repHit:FireAllInRangeExcept(player, position, config.maxHitDistance, weapon, raycastResult, wepStats.ShellHitFX or "Hit_Light")

	-- Server-side hit effects
	local directHitPart:BasePart = raycastResult.Instance
	if directHitPart then 
		local victim:Humanoid = directHitPart.Parent:FindFirstChildWhichIsA("Humanoid")
		local victimPlayer:Player? = victim and players:GetPlayerFromCharacter(victim.Parent)
		local vehicle:Model = atmod.TagCheck(directHitPart, "Vehicles")
		local prop:Model = atmod.TagCheck(directHitPart, "Props")

		-- Tank damage
		if directHitPart:HasTag("Dragoon_Armor") and vehicle and not table.find(vehiclesHit, vehicle) then
			table.insert(vehiclesHit, vehicle)
			atmod.DamageVehicle(player, directHitPart, pen, dmg, knockback, true)
		elseif not vehicle then
			atmod.DamageMisc(player, directHitPart, directHitPart.Position, nil, pen, dmg, plrDmg, knockback, true)
		end
		-- Player damage
		if victim and victim.Health > 0 and not table.find(humanoidsHit, victim) then
			table.insert(humanoidsHit, victim)
			atmod.DamagePlayer(player, victim, plrDmg, knockback, true)
		end
		-- Prop damage
		if directHitPart:HasTag("PropSystem_Armor") and prop and not table.find(propsHit, prop) then
			table.insert(propsHit, prop)
			atmod.DamageProp(player, directHitPart, pen, dmg, knockback, true)
		end
	end

	--Explosion damage
	if wepStats.ExplosiveShell then
		local originPos = raycastResult.Position
		local blastRadius =  wepStats.ExplosiveRadius
		local partsInRange = workspace:GetPartBoundsInRadius(originPos, blastRadius * 2, explosionOverlapParams)

		--Explosion effects
		if config.explosionEffects then
			--print(wepStats.ExplosionEffect)
			explosionMod(raycastResult.Position, wepStats.ExplosiveRadius, wepStats.ExplosionEffect)
		end

		--Terrain damage
		if config.terrainExplosions then
			craterMod.CreateCrater(originPos, blastRadius, blastRadius*0.25, raycastResult.Material)
		end

		for _, hitPart in ipairs(partsInRange) do --Loop through all parts found in range
			--Get appropiate penetration and damage values based on distance and range
			local dist = (originPos - hitPart.Position).Magnitude
			local AOE_Dmg = math.abs((1 - math.map(dist, 0, blastRadius*2, 0, 1))*dmg)
			local AOE_Pen = pen*0.5
			local AOE_PlrDmg = math.abs(blastRadius / 1.5 / dist*100 )
			local AOE_ShellForce =  (1-math.map(dist, 0, blastRadius*2, 0, 1))*wepStats.ShellForce 
			local AOE_Knockback = (config.useBulletForce and (originPos - hitPart.Position).Unit*-AOE_ShellForce) or nil --(originPos - hitPart.Position).Unit*-2000

			local victim = hitPart and hitPart.Parent and hitPart.Parent:FindFirstChildWhichIsA("Humanoid")
			local humanRoot = hitPart and hitPart.Parent and hitPart.Parent:FindFirstChild("HumanoidRootPart")
			local vehicle:Model = atmod.TagCheck(hitPart, "Vehicles")
			local prop:Model = atmod.TagCheck(hitPart, "Props")
			--if not targetVic then targetVic =  end

			--If a humanoid was hit and hadn't been hit before
			if victim and victim.Health > 0 and humanRoot and not table.find(humanoidsHit, victim) then
				local result = workspace:Raycast(originPos + Vector3.new(0,1,0), (humanRoot.Position - originPos).Unit*blastRadius, explosionRayParams)
				if not config.explosionRaycast or (result and result.Instance and result.Instance:IsDescendantOf(victim.Parent)) then
					table.insert(humanoidsHit, victim)
					if not victim.Sit then --Exclude people sitting
						atmod.DamagePlayer(player, victim, AOE_PlrDmg, AOE_Knockback, false)
					end 
				end
			end
			--If a tank was hit and hand't been hit before
			if vehicle and hitPart:HasTag("Dragoon_Armor") and not table.find(vehiclesHit, vehicle) then
				local vicPos = vehicle:GetPivot().Position
				local result = workspace:Raycast(originPos + Vector3.new(0,1,0), (vicPos - originPos).Unit*blastRadius, explosionRayParams)
				if not config.explosionRaycast or (result and result.Instance and result.Instance:IsDescendantOf(vehicle)) then
					table.insert(vehiclesHit, vehicle)
					atmod.DamageVehicle(player, hitPart, AOE_Pen, AOE_Dmg, AOE_Knockback, false)
				end
				atmod.DamageMisc(player, hitPart, hitPart.Position, originPos, AOE_Pen, AOE_Dmg, AOE_PlrDmg, nil, false)
			elseif not vehicle then
				atmod.DamageMisc(player, hitPart, hitPart.Position, originPos, AOE_Pen, AOE_Dmg, AOE_PlrDmg, AOE_Knockback, false)
			end
			--If a prop was hit and hadn't been hit before
			if prop and not table.find(propsHit, prop) then
				local result = workspace:Raycast(originPos + Vector3.new(0,1,0), (prop.WorldPivot.Position - originPos).Unit*blastRadius, explosionRayParams)
				if not config.explosionRaycast or (result and result.Instance and result.Instance:IsDescendantOf(prop)) then
					table.insert(propsHit, prop)
					atmod.DamageProp(player, hitPart, AOE_Pen, AOE_Dmg, AOE_Knockback, false)
				end
			end
		end
	end
end

local function GunEvent(player:Player, module, func, ...)
	local modFind = wmodules:FindFirstChild(module)
	if not modFind then return end

	local modReq = require(modFind)
	if modReq[func] then modReq[func](...) end
end

local function AddonEvent(player:Player, module, func, ...)
	local modFind = amodules:FindFirstChild(module)
	if not modFind then return end

	local modReq = require(modFind)
	if modReq[func] then modReq[func](...) end
end

local function AttributeSet(player:Player, part:Instance, attribute:string, value:any, module:ModuleScript?)
	if not module or not module:IsDescendantOf(assets) then return end
	if not table.find(validAttributes, attribute) then return end
	if not part:IsA("Model") and not part:IsA("Folder") then return end

	local isVehicle = part:HasTag("Dragoon_Vehicle")
	local isWeapon = part and part.Parent and part.Parent.Parent and part.Parent.Parent:HasTag("Dragoon_Vehicle")
	if not isVehicle and not isWeapon then return end

	part:SetAttribute(attribute, value)
end

local function ExitTank(player:Player, gui:ScreenGui)
	local dtsUI = player.PlayerGui:FindFirstChild("DTS_UI")
	if not dtsUI or not gui then return end 

	if not gui:IsA("ScreenGui") or gui~=dtsUI then print("DTS_Server: "..player.Name.." tried to exploit DTS functions!!") return end
	dtsUI:Destroy()
end

--// Connections
rotateAssembly:Connect(RotateAssemblyHinges)
exitTank:Connect(ExitTank)
attSet:Connect(AttributeSet)
getOwner:Connect(GetOwner)
playerFire:Connect(PlayerFire)
playerReload:Connect(PlayerReload)
vehicleReplenish:Connect(VehicleReplenish)
bulletHit:Connect(BulletHit)
bulletRepFocus:Connect(BulletRepFocus)
gunEvent:Connect(GunEvent)
modEvent:Connect(AddonEvent)
forceReload.Event:Connect(PlayerReload)

for _, vic in pairs(collection:GetTagged("Dragoon_Vehicle")) do
	if vic:HasTag("Okami_Chassis") or vic:HasTag("Dragoon_Spaceship") or vic:HasTag("INTERACT_LOADED") then continue end
	if not vic:IsDescendantOf(workspace) then continue end
	setup.LoadVic(vic)
end

warn(config.prefix.." Main server loaded successfully!")

--[[ OLD AOE DAMAGE FORMULAS
local AOE_Pen = math.floor((dist>blastRadius and 0) or (dist <= blastRadius*0.25) and pen or math.map(dist, blastRadius*0.25, blastRadius, pen, pen*0.25))
			local AOE_Dmg = math.floor((dist>blastRadius and 0) or (dist <= blastRadius*0.25) and dmg or math.map(dist, blastRadius*0.25, blastRadius, dmg, dmg*0.25))

	local distMult = math.clamp(math.map(dist, blastRadius*0.25, blastRadius, 0, 0.75), 0, 0.75)
	local AOE_Pen = (dist>blastRadius*0.25 and pen*(0.75-distMult)) or pen
	local AOE_Dmg = (dist>blastRadius*0.25 and dmg*(0.75-distMult)) or dmg
--]]