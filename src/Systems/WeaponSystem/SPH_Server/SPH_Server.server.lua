-- Monolithic server script (controller logic inlined).
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local Utility = replicatedStorage:WaitForChild("Utility")
local debris = game:GetService("Debris")
local proxPromptService = game:GetService("ProximityPromptService")
local _collectionService = game:GetService("CollectionService")
local physicsService = game:GetService("PhysicsService")

physicsService:RegisterCollisionGroup("Casings")
physicsService:RegisterCollisionGroup("Players")
physicsService:RegisterCollisionGroup("RootParts")
physicsService:RegisterCollisionGroup("Guns")
physicsService:RegisterCollisionGroup("SuppressionTargets")
physicsService:CollisionGroupSetCollidable("Casings", "Casings", false)
physicsService:CollisionGroupSetCollidable("Casings", "Players", false)
physicsService:CollisionGroupSetCollidable("Guns", "Guns", false)
physicsService:CollisionGroupSetCollidable("Guns", "Players", false)
physicsService:CollisionGroupSetCollidable("Casings", "Guns", false)

physicsService:CollisionGroupSetCollidable("SuppressionTargets", "Players", false)
physicsService:CollisionGroupSetCollidable("SuppressionTargets", "Guns", false)
physicsService:CollisionGroupSetCollidable("SuppressionTargets", "Casings", false)
physicsService:CollisionGroupSetCollidable("SuppressionTargets", "Default", false)
local Framework = replicatedStorage.SPH_Framework
local Access = require(Framework.Access)
local assets = Access.assets
local config = Access.config
local mainui = assets.HUD.SPH_UI

require(Utility.TestRunner)(Framework.Tests)

local WeaponStatLocator = require(Framework.Weapons.WeaponStatLocator)
local weldMod = require(Framework.Weapons.WeldMod)
local NetworkEvents = require(Framework.Network.NetworkEvents)
local NetUtil = require(Framework.Network.NetUtil)
local viewMod = require(Framework.Weapons.ViewMod)
local explosionMod = require(Framework.Effects.ExplosionFX)
local ragdoll = require(Framework.Effects.RagdollMod)
local HitContextTypes = require(Framework.Combat.HitContextTypes)
local VictimFinder = require(Framework.Combat.VictimFinder)
local attachmentPlacer = require(Framework.Weapons.AttachmentPlacer)
local WeaponSoundSetup = require(Framework.Weapons.WeaponSoundSetup)
local Types = require(Framework.Core.ConfigurationTypes)
local warnPrefix = "【 SPEARHEAD 】 "
print(warnPrefix .. "Loading Server " .. config.version)

local dtsInstall = replicatedStorage:FindFirstChild("DTS_Assets")
local atmod
if dtsInstall then
	atmod = require(dtsInstall.Modules.Antitank)
end

local explosionRayParams = RaycastParams.new()
explosionRayParams.IgnoreWater = true

local explosionOverlapParams = OverlapParams.new()
explosionOverlapParams.MaxParts = 500

local net = NetworkEvents

local naughtyList = {}
game:GetService("SoundService").RespectFilteringEnabled = true
require(script.Parent.CreateSoundGroups)()

local mainFolder = Instance.new("Folder", workspace)
mainFolder.Name = "SPH_Workspace"
local projectiles = Instance.new("Folder", mainFolder)
projectiles.Name = "Projectiles"
local cache = Instance.new("Folder", mainFolder)
cache.Name = "Cache"
local bodies = Instance.new("Folder", mainFolder)
bodies.Name = "Bodies"
local shells = Instance.new("Folder", mainFolder)
shells.Name = "Shells"
local drops = Instance.new("Folder", mainFolder)
drops.Name = "Drops"

local dropTable = {}
local dropCFrame = CFrame.new(0, 1, -3)
local bodyparts = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }

local function setAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	local newAttachment = attachmentPlacer.place(assets, weldMod, weapon, attachmentSlot, weaponAttachment, parentPart)
	if not newAttachment then
		return
	end
	for _, part in ipairs(newAttachment:GetChildren()) do
		if part.Name == "SightReticle" and part:FindFirstChild("SurfaceGui") then
			part.SurfaceGui.Enabled = false
		end
	end
end

local function setRecursiveAttachments(weapon, attachmentSlot, weaponAttachment, parentPart)
	if not weaponAttachment or weaponAttachment == "" then
		return
	end
	if typeof(weaponAttachment) == "string" then
		if not parentPart:FindFirstChild(attachmentSlot) then
			warn("No slot found for " .. weaponAttachment)
			return
		end
		setAttachment(weapon, attachmentSlot, weaponAttachment, parentPart)
	elseif typeof(weaponAttachment) == "table" then
		local subAttachment = weaponAttachment[1]
		local subAttachmentNodes = weaponAttachment[2]
		setAttachment(weapon, attachmentSlot, subAttachment, parentPart)
		for item, name in pairs(subAttachmentNodes) do
			setRecursiveAttachments(weapon, item, name, weapon[subAttachment])
		end
	end
end

local function enableMotors(char: Model)
	for i = 1, #bodyparts do
		local charArm = char:FindFirstChild(bodyparts[i])
		if charArm then
			for _, motor in pairs(charArm:GetChildren()) do
				if motor:IsA("Motor6D") then
					motor.Enabled = true
				end
			end
		end
	end
end

local function makeCharacterRig(char: Model)
	local head = char:WaitForChild("Head", 20)
	local humanoid = char:FindFirstChildWhichIsA("Humanoid")
	local rig = viewMod.RigModel(nil, true, head)
	rig.Parent = char
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local lArmWeld = weldMod.BlankWeld(rig["Left Arm"], char["Left Arm"])
		lArmWeld.Parent = rig
		lArmWeld.Name = "law"
		rig["Left Arm"].Transparency = 1
		local rArmWeld = weldMod.BlankWeld(rig["Right Arm"], char["Right Arm"])
		rArmWeld.Parent = rig
		rArmWeld.Name = "raw"
		rig["Right Arm"].Transparency = 1
	else
		for i = 1, #bodyparts do
			local rigArm = rig[bodyparts[i]]
			local charArm = char[bodyparts[i]]
			local weld = weldMod.BlankWeld(rigArm, charArm)
			weld.Parent = rig
			weld.Name = bodyparts[i] .. "_w"
			rigArm.Transparency = 1
			weld.Enabled = false
		end
		enableMotors(char)
	end
	local animController = Instance.new("AnimationController", rig)
	Instance.new("Animator", animController)
	return rig
end

local function removeHolster(player, toolName)
	if player.Character then
		local holsterModel = player.Character:FindFirstChild("Holster_" .. toolName)
		if holsterModel and not player.Backpack:FindFirstChild(toolName) then
			holsterModel:Destroy()
		end
	end
end

local function setupTool(tool: Tool, wepStats: Types.WeaponStats)
	tool.CanBeDropped = false

	if not tool:FindFirstChild("Ammo") then
		local ammoFolder = Instance.new("Folder", tool)
		ammoFolder.Name = "Ammo"
		local magAmmo = Instance.new("DoubleConstrainedValue", ammoFolder)
		magAmmo.Name = "MagAmmo"
		magAmmo.MaxValue = wepStats.magazineCapacity
		magAmmo.Value = wepStats.magazineAmmo or magAmmo.MaxValue
		local arcadeAmmoPool = Instance.new("DoubleConstrainedValue", ammoFolder)
		arcadeAmmoPool.Name = "ArcadeAmmoPool"
		arcadeAmmoPool.MaxValue = Access.config.infiniteReserve and math.huge or wepStats.maxAmmoPool
		arcadeAmmoPool.Value = Access.config.infiniteReserve and math.huge or wepStats.startAmmoPool
		if not wepStats.openBolt then
			local chambered = Instance.new("BoolValue", tool)
			chambered.Value = wepStats.startChambered
			chambered.Name = "Chambered"
			if chambered.Value then
				if magAmmo.Value > 0 then
					magAmmo.Value -= 1
				else
					chambered.Value = false
				end
			end
		end
		local boltReady = Instance.new("BoolValue", tool)
		boltReady.Value = true
		boltReady.Name = "BoltReady"
		local fireMode = Instance.new("IntValue", tool)
		fireMode.Value = wepStats.fireMode
		fireMode.Name = "FireMode"
	end
end

local function holsterWeapon(player, holsterPart, tool, holsterCFrame)
	local holsterModel
	local wepStats = WeaponStatLocator.getWeaponStats(tool)
	if not assets.WeaponModels.HolsterModels:FindFirstChild(tool.Name) then
		holsterModel = assets.WeaponModels:FindFirstChild(tool.Name):Clone()
		holsterModel.Name = "Holster_" .. tool.Name
		weldMod.WeldModel(holsterModel, holsterModel.Grip)
		local holsterWeld = weldMod.BlankWeld(holsterPart, holsterModel.Grip)
		holsterWeld.Name = "HolsterWeld"
		holsterWeld.C0 = holsterCFrame
		holsterWeld.Parent = holsterModel
		holsterModel.Parent = player.Character
	else
		holsterModel = assets.WeaponModels.HolsterModels:FindFirstChild(tool.Name):Clone()
		holsterModel.Name = "Holster_" .. tool.Name
		weldMod.WeldModel(holsterModel, holsterModel.Middle)
		local holsterWeld = weldMod.BlankWeld(holsterPart, holsterModel.Middle)
		holsterWeld.Name = "HolsterWeld"
		holsterWeld.Parent = holsterModel
		holsterModel.Parent = player.Character
		holsterModel.Middle.Name = "Grip"
		holsterModel.Grip.Transparency = 1
	end
	if wepStats.Attachments then
		for slot, item in wepStats.Attachments do
			if typeof(item) == "string" then
				if not holsterModel:FindFirstChild(slot) then
					warn("No slot found for " .. slot)
					continue
				end
				setAttachment(holsterModel, slot, item, holsterModel)
			elseif typeof(item) == "table" then
				setRecursiveAttachments(holsterModel, slot, item, holsterModel)
			else
				warn("Node type" .. (slot ~= nil and typeof(slot) or "nil") .. "not recognized")
			end
		end
	end
	if tool:FindFirstChild("Chambered") and holsterModel and holsterModel:FindFirstChild(wepStats.projectile) and not tool.Chambered.Value then
		local projectile = holsterModel:FindFirstChild(wepStats.projectile)
		projectile:Destroy()
	end
end

local function checkHolster(player, tool)
	local wepStats = WeaponStatLocator.getWeaponStats(tool)
	if not wepStats then
		return
	end
	if wepStats.holster then
		local holsterPart = player.Character:FindFirstChild(wepStats.holsterPart)
		if wepStats.holsterPart_R15 and player.Character.Humanoid.RigType == Enum.HumanoidRigType.R15 then
			holsterPart = player.Character:FindFirstChild(wepStats.holsterPart_R15)
		end
		if player.Character
			and not player.Character:FindFirstChild("Holster_" .. tool.Name)
			and not player.Character:FindFirstChild(tool.Name)
			and holsterPart
		then
			holsterWeapon(player, holsterPart, tool, wepStats.holsterPosition)
		end
	end
end


local function equipGun(rig: Model, tool: Tool, rigType: Enum.HumanoidRigType)
	if tool.Parent == rig.Parent and assets.WeaponModels:FindFirstChild(tool.Name) then
		local wepStats = WeaponStatLocator.getWeaponStats(tool)
		if not wepStats then
			return
		end

		local gun = assets.WeaponModels[tool.Name]:Clone()
		WeaponSoundSetup.apply(gun, wepStats, assets.Sounds)
		
		weldMod.WeldModel(gun, gun.Grip, false)

		for _, partName in ipairs(wepStats.rigParts) do
			if gun:FindFirstChild(partName) then
				gun.Grip["Grip_" .. partName]:Destroy()
				local newMotor = weldMod.M6D(gun.Grip, gun[partName])
				newMotor.Name = partName
				newMotor.Parent = gun.Grip
			end
		end
		if wepStats.Attachments then
			for slot, item in wepStats.Attachments do
				if typeof(item) == "string" then
					if not gun:FindFirstChild(slot) then
						warn("No slot found for " .. slot)
						continue
					end
					setAttachment(gun, slot, item, gun)
				elseif typeof(item) == "table" then
					setRecursiveAttachments(gun, slot, item, gun)
				else
					warn("Node type" .. (slot ~= nil and typeof(slot) or "nil") .. "not recognized")
				end
			end
		end
		for _, part in ipairs(gun:GetDescendants()) do
			if part.Name == "SightReticle" and part:FindFirstChild("SurfaceGui") then
				part.SurfaceGui.Enabled = false
			end
		end
		gun.Parent = rig.Weapon
		if rig.AnimBase:FindFirstChild("GunMotor") then
			rig.AnimBase:FindFirstChild("GunMotor"):Destroy()
		end
		local gunMotor = weldMod.BlankM6D(rig.AnimBase, gun.Grip)
		gunMotor.Name = "GunMotor"
		if rigType == Enum.HumanoidRigType.R6 then
			rig.law.Enabled = true
			rig.raw.Enabled = true
		else
			for i = 1, #bodyparts do
				rig[bodyparts[i] .. "_w"].Enabled = true
			end
		end
		rig.BaseWeld.C0 = wepStats.serverOffset
		setupTool(tool, wepStats)
		return gun
	end
	return nil
end

local function checkTool(player, tool)
	if _collectionService:HasTag(tool, "SPH_Weapon") and assets.WeaponModels:FindFirstChild(tool.Name) then
		local wepStats = WeaponStatLocator.getWeaponStats(tool)
		if not wepStats then
			return
		end
		checkHolster(player, tool)
		setupTool(tool, wepStats)
	end
end

local function makePickUpAble(tool, model, mainPart)
	tool.Parent = model
	model.Name = tool.Name
	local proxPrompt = Instance.new("ProximityPrompt")
	proxPrompt.MaxActivationDistance = config.pickupDistance
	proxPrompt.Style = Enum.ProximityPromptStyle.Custom
	proxPrompt.RequiresLineOfSight = false
	proxPrompt.KeyboardKeyCode = config.pickupKey[1]
	proxPrompt.HoldDuration = 0
	proxPrompt.Parent = mainPart
	local promptListener
	promptListener = proxPrompt.Triggered:Connect(function(player)
		if player.Character.Humanoid.Health <= 0 then
			return
		else
			promptListener:Disconnect()
		end
		tool.Parent = player.Backpack
		model:Destroy()
		local newSound = assets.Sounds.Misc.WeaponPickup:Clone()
		newSound.Parent = player.Character.HumanoidRootPart
		newSound:Play()
		newSound.PlayOnRemove = true
		newSound:Destroy()
	end)
	local highlight = Instance.new("Highlight")
	highlight.Name = "PickupHighlight"
	highlight.FillTransparency = 0.7
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.Parent = model
	highlight.Enabled = false
end

local function spawnGun(tool, gunPosition, dropPlayer)
	local dropModel = assets.WeaponModels:FindFirstChild(tool.Name)
	if not dropModel then
		return
	end
	dropModel = dropModel:Clone()
	dropModel.Grip.Anchored = false
	dropModel.Grip.CanTouch = true
	task.delay(config.dropGunAnchorTime, function()
		for _, desc in dropModel:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
			end
		end
	end)
	dropModel.PrimaryPart = dropModel.Grip
	dropModel.Grip.Size = dropModel:GetExtentsSize()
	if #dropModel:GetChildren() < 2 then
		dropModel.Grip.CanCollide = true
	else
		dropModel.Grip.CanCollide = false
	end
	for _, part in ipairs(dropModel:GetDescendants()) do
		if part:IsA("BasePart") then
			if string.find(part.Name, "AimPart") then
				part:Destroy()
			elseif part.Name ~= "Grip" then
				local newWeld = weldMod.Weld(dropModel.Grip, part)
				newWeld.Parent = dropModel.Grip
				part.Anchored = false
				part.CanCollide = true
				part.CanTouch = false
				part.CollisionGroup = "Guns"
			end
		end
	end
	if not tool then
		local clonedTool = assets.ToolStorage:FindFirstChild(dropModel.Name)
		if clonedTool then
			tool = clonedTool:Clone()
		else
			warn("No tool could be found for this pickup. Did you forget to put one in ToolStorage?")
			return
		end
	end
	makePickUpAble(tool, dropModel, dropModel.Grip)
	local wepStats = WeaponStatLocator.getWeaponStats(tool)
	if wepStats and wepStats.Attachments then
		for slot, item in wepStats.Attachments do
			if typeof(item) == "string" then
				if not dropModel:FindFirstChild(slot) then
					warn("No slot found for " .. slot)
					continue
				end
				setAttachment(dropModel, slot, item, dropModel)
			elseif typeof(item) == "table" then
				setRecursiveAttachments(dropModel, slot, item, dropModel)
			else
				warn("Node type" .. (slot ~= nil and typeof(slot) or "nil") .. "not recognized")
			end
		end
	end
	dropModel.Parent = drops
	dropModel.Grip.Touched:Connect(function()
		if dropModel.Grip.AssemblyLinearVelocity.Magnitude > 7 then
			local dropSounds = assets.Sounds.GunDrop
			local newSound = dropSounds["GunDrop" .. math.random(#dropSounds:GetChildren())]:Clone()
			newSound.Parent = dropModel.Grip
			newSound.PlaybackSpeed = math.random(30, 50) / 40
			newSound:Play()
			newSound.PlayOnRemove = true
			newSound:Destroy()
		end
	end)
	if dropPlayer then
		dropModel.Grip:SetNetworkOwner(dropPlayer)
	end
	dropModel:SetPrimaryPartCFrame(gunPosition)
	local position = #dropTable + 1
	table.insert(dropTable, position, dropModel)
	if #dropTable > config.maxDroppedGuns then
		local objectToDestroy = dropTable[1]
		table.remove(dropTable, 1)
		objectToDestroy:Destroy()
	end
	task.delay(config.dropDespawnTime, function()
		table.remove(dropTable, position)
		dropModel:Destroy()
	end)
	return dropModel
end

local function initializePlayerLifecycle()
	players.PlayerAdded:Connect(function(newPlayer: Player)
		print(warnPrefix .. newPlayer.Name .. " joined the server")
		if config.serverBanList and table.find(naughtyList, newPlayer.UserId) then
			newPlayer:Kick("Disconnected")
			warn(warnPrefix .. newPlayer.Name .. " attempted to join a server they've been banned from")
			return
		elseif config.strikes then
			newPlayer:SetAttribute("Strikes", 0)
			newPlayer:GetAttributeChangedSignal("Strikes"):Connect(function()
				if newPlayer:GetAttribute("Strikes") >= config.maxStrike then
					table.insert(naughtyList, newPlayer.UserId)
					newPlayer:Kick("Disconnected")
					warn(
						warnPrefix
							.. newPlayer.Name
							.. " was kicked for reaching "
							.. newPlayer:GetAttribute("Strikes")
							.. " strikes. Last strike reason: '"
							.. newPlayer:GetAttribute("LastStrikeReason")
							.. "'"
					)
				end
			end)
		end
		local deaths
		if config.leaderboard then
			local leaderstats = newPlayer:FindFirstChild("leaderstats")
			if not leaderstats then
				leaderstats = Instance.new("Folder", newPlayer)
				leaderstats.Name = "leaderstats"
			end
			local kills = Instance.new("IntValue", leaderstats)
			kills.Name = config.leaderboardKillStat
			deaths = Instance.new("IntValue", leaderstats)
			deaths.Name = config.leaderboardDeathStat
			local teamKills = Instance.new("IntValue", leaderstats)
			teamKills.Name = config.leaderboardTKStat
		end
		newPlayer.CharacterAdded:Connect(function(newChar: Model)
			newChar.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			newChar:AddTag("SPH_Character")
			
			print(warnPrefix .. newPlayer.Name .. " spawned.")
			local head = newChar:WaitForChild("Head", 20) :: Instance
			local humanoid = newChar:WaitForChild("Humanoid", 20)
			humanoid:WaitForChild("Animator", 20)
			local newRig = makeCharacterRig(newChar)
			if config.ragdolls then
				humanoid.BreakJointsOnDeath = false
			end

			if config.fixHeadHitboxes then
				head.Size = Vector3.new(1, 1, 1)
			end

			humanoid.Died:Connect(function()
				if not newChar:FindFirstChild("HumanoidRootPart") then
					return
				end
				newChar.Humanoid:UnequipTools()
				local robloxDamageTag = newChar.Humanoid:FindFirstChildWhichIsA("ObjectValue")
				local killer = newChar:FindFirstChild("Killer")
				if killer and robloxDamageTag and robloxDamageTag.Value and robloxDamageTag.Value:IsA("Player") and config.rblxDamageTags then
					killer = robloxDamageTag
				end
				newRig:Destroy()
				if config.leaderboard then
					deaths.Value += 1
				end
				local hrp, newBody
				if config.ragdolls and newChar:FindFirstChild("HumanoidRootPart") then
					newBody = ragdoll.MakeCorpse(newChar)
					newBody.Parent = bodies
					hrp = newBody.HumanoidRootPart
					debris:AddItem(newBody, config.bodyDespawn)
					if #bodies:GetChildren() > config.bodyLimit then
						bodies:GetChildren()[1]:Destroy()
					end
					local torso
					if humanoid.RigType == Enum.HumanoidRigType.R6 then
						torso = newBody.Torso
					else
						torso = newBody.UpperTorso
					end
					local deathForce = Instance.new("VectorForce", torso.NeckAttachment)
					deathForce.Attachment0 = deathForce.Parent
					deathForce.Force = Vector3.new(0, 0, -600)
					debris:AddItem(deathForce, 0.2)
					task.delay(config.bodyAnchorTime, function()
						for _, desc in newBody:GetDescendants() do
							if desc:IsA("BasePart") then
								desc.Anchored = true
								desc.CanCollide = false
							elseif desc:IsA("Constraint") then
								desc.Enabled = false
							end
						end
					end)
				else
					hrp = newChar.HumanoidRootPart
				end
				if config.dropOnDeath then
					local equippedTool = newChar:FindFirstChildWhichIsA("Tool")
					if equippedTool and _collectionService:HasTag(equippedTool, "SPH_Weapon") then
						spawnGun(equippedTool, newChar.HumanoidRootPart.CFrame * dropCFrame, newPlayer)
					end
					for _, tool in ipairs(newPlayer.Backpack:GetChildren()) do
						local holsterModel = newBody and newBody:FindFirstChild("Holster_" .. tool.Name)
						if holsterModel and newBody then
							makePickUpAble(tool, holsterModel, holsterModel.Grip)
						else
							spawnGun(tool, newBody.HumanoidRootPart.CFrame * dropCFrame, newPlayer)
							task.wait()
						end
					end
				end
				local deathSounds = assets.Sounds.Death:GetChildren()
				local newSound = deathSounds[math.random(#deathSounds)]:Clone()
				newSound.Parent = hrp
				newSound:Play()
				debris:AddItem(newSound, newSound.TimeLength)
			end)
			newPlayer.Backpack.ChildAdded:Connect(function(child)
				checkTool(newPlayer, child)
			end)
			newPlayer.Backpack.ChildRemoved:Connect(function(child)
				if _collectionService:HasTag(child, "SPH_Weapon") then
					removeHolster(newPlayer, child.Name)
				end
			end)
			for _, tool in ipairs(newPlayer.Backpack:GetChildren()) do
				checkTool(newPlayer, tool)
			end
			for _, part in ipairs(newChar:GetChildren()) do
				if part:IsA("BasePart") then
					if part.Name == "HumanoidRootPart" then
						part.CollisionGroup = "RootParts"
					else
						part.CollisionGroup = "Players"
					end
				end
			end
			local humanoidRootPart = newChar.HumanoidRootPart
			local soundOrigin = Instance.new("Attachment", humanoidRootPart)
			soundOrigin.Name = "FootstepSoundOrigin"
			soundOrigin.Position = Vector3.new(0, -3, 0)
			local leftFoot = Instance.new("Sound", soundOrigin)
			leftFoot.Name = "LeftFoot"
			leftFoot.Volume = 1
			leftFoot.RollOffMode = Enum.RollOffMode.InverseTapered
			leftFoot.RollOffMaxDistance = 100
			local rightFoot = Instance.new("Sound", soundOrigin)
			rightFoot.Name = "RightFoot"
			rightFoot.Volume = 1
			rightFoot.RollOffMode = Enum.RollOffMode.InverseTapered
			rightFoot.RollOffMaxDistance = 100
			task.wait()
			local newGui = mainui:Clone()
			newGui.Parent = newPlayer.PlayerGui
			if config.deathScreen then
				assets.HUD.DeathScreen:Clone().Parent = newPlayer.PlayerGui
			end
		end)
	end)
	players.PlayerRemoving:Connect(function(player)
		print(warnPrefix .. player.Name .. " left the server")
		local character = player.Character
		if config.dropOnLeave and character then
			local equippedTool = character:FindFirstChildWhichIsA("Tool")
			if equippedTool and _collectionService:HasTag(equippedTool, "SPH_Weapon") then
				spawnGun(equippedTool, character.HumanoidRootPart.CFrame * dropCFrame, player)
			end
			for _, tool in ipairs(player.Backpack:GetChildren()) do
				spawnGun(tool, character.HumanoidRootPart.CFrame * dropCFrame, player)
				task.wait()
			end
		end
	end)
end

local function checkNaughtyList(playerID)
	return table.find(naughtyList, playerID) ~= nil
end

local function isGunLoaded(tool)
	local wepStats = WeaponStatLocator.getWeaponStats(tool)
	local gunAmmo = tool.Ammo
	return not wepStats.openBolt and tool.Chambered.Value or wepStats.openBolt and gunAmmo.MagAmmo.Value > 0
end

local function teamKillCheck(player1: Player, player2: Player)
	if not config.teamKill and not player1.Neutral and not player2.Neutral then
		if player1.Team == player2.Team then
			return false
		end
	end
	return true
end

local function equippedToolFromBridge(tool)
	if typeof(tool) == "table" and tool.Tool then
		return tool.Tool
	end
	return tool
end

local function weaponStatsForBridgeTool(tool)
	if typeof(tool) == "table" then
		if tool.model then
			return require(tool.model.Parent.TurretModule).guns[tool.index]
		end
		return WeaponStatLocator.getWeaponStats(tool.Tool)
	end
	if tool:IsA("Tool") then
		return WeaponStatLocator.getWeaponStats(tool)
	end
	return nil
end

local function onBulletHit(player: Player, tool: Tool, raycastResult: RaycastResult, bulletCFrame: CFrame)
	if not tool then
		return
	end
	if typeof(tool) ~= "Instance" and typeof(tool) ~= "table" then
		warn(warnPrefix .. player.Name .. " attempted to call bulletHit without a tool.")
		return
	end
	local equippedTool = equippedToolFromBridge(tool)
	if config.ammoCountCheck then
		local lastGun = player:GetAttribute("LastFiredGun")
		if lastGun and player.Character then
			local lastMag = player:GetAttribute("LastFiredMagCount")
			if player.Character:FindFirstChild(lastGun) and lastMag == equippedTool.Ammo.MagAmmo.Value then
				return
			end
		end
		player:SetAttribute("LastFiredGun", equippedTool.Name)
		player:SetAttribute("LastFiredMagCount", equippedTool.Ammo.MagAmmo.Value)
	end
	if checkNaughtyList(player.UserId) then
		return
	end
	if config.requireEquippedGun and equippedTool.Parent ~= player.Character then
		if config.strikes then
			player:SetAttribute("Strikes", (tonumber(player:GetAttribute("Strikes")) or 0) + 1)
			player:SetAttribute("LastStrikeReason", "Attempting to deal damage with no tool equipped")
		end
		return
	end
	if equippedTool.Parent ~= player.Character and equippedTool.Parent ~= player.Backpack then
		return
	end
	local wepStats = weaponStatsForBridgeTool(tool)
	if not wepStats then
		return
	end
	if wepStats.explosiveAmmo then
		local expRadius = wepStats.explosionRadius
		local expEffect = wepStats.explosionEffect
		if atmod then
			local expDmg = math.abs(math.random(wepStats.ATDefaultDamage[1], wepStats.ATDefaultDamage[2]))
			local expPen = math.abs(math.random(wepStats.ATDefaultPen[1], wepStats.ATDefaultPen[2]))
			local vehiclesHit = {}
			local propsHit = {}
			local originPos = raycastResult.Position
			local partsInRange = workspace:GetPartBoundsInRadius(originPos, expRadius * 2, explosionOverlapParams)
			for _, hitPart in ipairs(partsInRange) do
				local dist = (originPos - hitPart.Position).Magnitude
				local aoeDmg = math.abs((1 - math.map(dist, 0, expRadius * 2, 0, 1)) * expDmg)
				local aoePen = expPen * 0.5
				local aoePlrDmg = math.abs(expRadius / 1.5 / dist * 100)
				local aoeShellForce = (1 - math.map(dist, 0, expRadius * 2, 0, 1)) * wepStats.bulletForce
				local aoeKnockback = (config.useBulletForce and (originPos - hitPart.Position).Unit * -aoeShellForce) or nil
				local vehicle: Model = atmod.TagCheck(hitPart, "Vehicles")
				local prop: Model = atmod.TagCheck(hitPart, "Props")
				local vehiclePrimary = vehicle and vehicle.PrimaryPart
				if vehicle and vehiclePrimary and hitPart:HasTag("Dragoon_Armor") and not table.find(vehiclesHit, vehicle) then
					local result =
						workspace:Raycast(originPos + Vector3.new(0, 1, 0), (vehiclePrimary.Position - originPos).Unit * expRadius, explosionRayParams)
					if not config.explosionRaycast or (result and result.Instance and result.Instance:IsDescendantOf(vehicle)) then
						table.insert(vehiclesHit, vehicle)
						atmod.DamageVehicle(player, hitPart, aoePen, aoeDmg, aoeKnockback, false)
					end
					atmod.DamageMisc(player, hitPart, hitPart.Position, originPos, aoePen, aoeDmg, aoePlrDmg, nil, false)
				elseif not vehicle then
					atmod.DamageMisc(player, hitPart, hitPart.Position, originPos, aoePen, aoeDmg, aoePlrDmg, aoeKnockback, false)
				end
				if prop and not table.find(propsHit, prop) then
					local result = workspace:Raycast(originPos + Vector3.new(0, 1, 0), (prop.WorldPivot.Position - originPos).Unit * expRadius, explosionRayParams)
					if not config.explosionRaycast or (result and result.Instance and result.Instance:IsDescendantOf(prop)) then
						table.insert(propsHit, prop)
						atmod.DamageProp(player, hitPart, aoePen, aoeDmg, aoeKnockback, false)
					end
				end
			end
		end
		explosionMod(raycastResult.Position, expRadius, expEffect, player)
	else
		local position = raycastResult.Position
		local U, P = NetUtil, net.packets
		P.ReplicateHit.sendToList({ toolData = tool, rayHit = raycastResult }, U.playersInRangeExcept(U.asBlacklist(player), position, config.maxHitDistance))
	end
	local hitInst = raycastResult.Instance
	if not hitInst or not hitInst:IsA("BasePart") or not hitInst.Parent then
		return
	end
	local hitPart = hitInst :: BasePart
	local humanoid = hitPart.Parent:FindFirstChildWhichIsA("Humanoid")
	local otherPlayer
	if humanoid then
		otherPlayer = players:GetPlayerFromCharacter(humanoid.Parent)
	end
	local allowHumanDamage = not otherPlayer or teamKillCheck(player, otherPlayer)
	local hitContext: HitContextTypes.HitContext = {
		player = player,
		tool = tool,
		equippedTool = equippedTool,
		wepStats = wepStats,
		raycastResult = raycastResult,
		bulletCFrame = bulletCFrame,
		hitPart = hitPart,
		humanoid = humanoid,
		otherPlayer = otherPlayer,
		allowHumanDamage = allowHumanDamage,
	}
	if not VictimFinder.processDirectHit(hitContext) then
		return
	end
end

local function playerFireHandler(player: Player, firePoint: CFrame)
	local tool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
	if not tool or not tool:IsA("Tool") then
		warn(warnPrefix .. "PlayerFire Canceled: No tool was found.")
		return
	end
	local wepStats = WeaponStatLocator.getWeaponStats(tool)
	local gunAmmo = tool.Ammo
	local magAmmo = gunAmmo.MagAmmo
	local currentFireMode = tool.FireMode.Value
	if currentFireMode == 5 then
		if not wepStats.openBolt then
			tool.Chambered.Value = false
		end
		tool.BoltReady.Value = false
	elseif not isGunLoaded(tool) then
		if tool.BoltReady.Value then
			return
		elseif wepStats.emptyCloseBolt then
			tool.BoltReady.Value = true
			return
		end
	else
		if not wepStats.openBolt then
			tool.Chambered.Value = false
		end
		tool.BoltReady.Value = not wepStats.emptyLockBolt
		if magAmmo.Value > 0 then
			magAmmo.Value -= 1
			if not wepStats.openBolt then
				tool.Chambered.Value = true
			end
			tool.BoltReady.Value = true
		end
	end
	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end
	local point = rootPart.Position
	local dist = config.fireEffectDistance
	local U, P = NetUtil, net.packets
	P.ReplicateFire.sendToList({ shooter = player, firePoint = firePoint }, U.playersInRangeExcept(U.asBlacklist(player), point, dist))
end

local function initializeCombat()
	local glassBreakFolder = assets.Sounds:FindFirstChild("GlassBreak")
	local glassBreakSounds = glassBreakFolder and glassBreakFolder:GetChildren() or {}
	VictimFinder.Initialize({
		dts = {
			atmod = atmod,
			useBulletForce = config.useBulletForce,
		},
		human = {
			leaderboard = config.leaderboard,
			leaderboardTKStat = config.leaderboardTKStat,
			leaderboardKillStat = config.leaderboardKillStat,
		},
		glass = {
			glassShatter = config.glassShatter,
			glassRespawnTime = config.glassRespawnTime,
			glassBreakSounds = glassBreakSounds,
		},
		bulletImpulse = {
			enabled = config.useBulletForce,
		},
	})
	net.packets.PlayerFire.listen(function(data, player)
		if not player then
			return
		end
		playerFireHandler(player, data.firePoint)
	end)
	net.packets.BulletHit.listen(function(data, player)
		if not player then
			return
		end
		onBulletHit(player, data.toolData, data.rayHit, data.bulletCFrame)
	end)
end

local function initializeAmmo()
	local P, U = net.packets, NetUtil
	P.Reload.listen(function(_data, player: Player?)
		if not player then
			return
		end
		if config.listenForReloadSpam then
			if player:GetAttribute("LastReload") then
				if time() - player:GetAttribute("LastReload") <= 0.3 then
					return
				end
			end
			player:SetAttribute("LastReload", time())
		end
		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		if not tool then
			return
		end
		local wepStats = WeaponStatLocator.getWeaponStats(tool)
		local magAmmo = tool.Ammo.MagAmmo
		local arcadeAmmoPool = tool.Ammo.ArcadeAmmoPool
		local currentFireMode = tool.FireMode.Value
		if currentFireMode == 4 then
			return
		end
		if not wepStats.operationType or type(wepStats.operationType) == "string" then
			wepStats.operationType = 1
		end
		if not wepStats.magType or type(wepStats.magType) == "string" then
			wepStats.magType = 1
		end
		if wepStats.infiniteAmmo then
			if wepStats.magType == 2 then
				magAmmo.Value += 1
			elseif wepStats.magType == 3 then
				local ammoNeeded = magAmmo.MaxValue - magAmmo.Value
				local clipSize = wepStats.clipSize or wepStats.magazineCapacity
				if ammoNeeded >= clipSize then
					magAmmo.Value += clipSize
				else
					magAmmo.Value += 1
				end
			else
				magAmmo.Value = magAmmo.MaxValue
			end
		elseif arcadeAmmoPool.Value > 0 then
			if wepStats.magType == 1 or wepStats.magType == 4 then
				local ammoNeeded = magAmmo.MaxValue - magAmmo.Value
				if arcadeAmmoPool.Value > ammoNeeded then
					magAmmo.Value = magAmmo.MaxValue
					arcadeAmmoPool.Value -= ammoNeeded
				else
					magAmmo.Value += arcadeAmmoPool.Value
					arcadeAmmoPool.Value = 0
				end
			elseif wepStats.magType == 2 then
				if arcadeAmmoPool.Value > 0 then
					magAmmo.Value += 1
					arcadeAmmoPool.Value -= 1
				end
			elseif wepStats.magType == 3 then
				local ammoNeeded = magAmmo.MaxValue - magAmmo.Value
				local clipSize = wepStats.clipSize or wepStats.magazineCapacity
				if ammoNeeded >= clipSize and arcadeAmmoPool.Value >= ammoNeeded then
					magAmmo.Value += clipSize
					arcadeAmmoPool.Value -= clipSize
				else
					magAmmo.Value += 1
					arcadeAmmoPool.Value -= 1
				end
			end
		end
		if wepStats.operationType == 4 and not tool.Chambered.Value then
			tool.Chambered.Value = true
			magAmmo.Value -= 1
		end
	end)
	P.PlayerChamber.listen(function(_data, player: Player?)
		if not player then
			return
		end
		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		if tool and tool.Parent == player.Character then
			tool.BoltReady.Value = true
			if tool:FindFirstChild("Chambered") then
				tool.Chambered.Value = false
			end
			if tool.Ammo.MagAmmo.Value > 0 and tool:FindFirstChild("Chambered") then
				tool.Ammo.MagAmmo.Value -= 1
				tool.Chambered.Value = true
			end
		end
	end)
	P.RepBoltOpen.listen(function(_data, player: Player?)
		if not player then
			return
		end
		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		if tool and tool.Parent == player.Character then
			tool.BoltReady.Value = false
			if tool:FindFirstChild("Chambered") then
				tool.Chambered.Value = false
			end
		end
	end)
	P.SwitchFireMode.listen(function(data, player: Player?)
		if not player then
			return
		end
		local newFireMode = data.mode
		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		if tool and _collectionService:HasTag(tool, "SPH_Weapon") then
			if newFireMode == 4 then
				return
			end
			tool.FireMode.Value = newFireMode
		end
	end)
	P.MoveBolt.listen(function(data, player: Player?)
		if not player then
			return
		end
		local playerPosition = player.Character.HumanoidRootPart.Position
		P.ReplicateBolt.sendToList(
			{ shooter = player, direction = data.direction, magAmmo = data.magAmmo },
			U.playersInRangeExcept(U.asBlacklist(player), playerPosition, config.fireEffectDistance)
		)
	end)
end

local function initializeServerReplication()
	local P, U = net.packets, NetUtil
	P.BodyAnimRequest.listen(function(data, player: Player?)
		if not player then
			return
		end
		local char = player.Character
		if char and (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")) and char.Humanoid.Health > 0 then
			char:SetAttribute("BodyRot", data.neckC1)
		end
	end)
	P.PlayerLean.listen(function(data, player: Player?)
		if not player then
			return
		end
		local char = player.Character
		if char then
			char:SetAttribute("Lean", data.lean)
		end
	end)
	P.PlaySound.listen(function(data, player: Player?)
		if not player then
			return
		end
		local weapon = player.Character.WeaponRig.Weapon:FindFirstChildWhichIsA("Model")
		if not weapon then
			warn(warnPrefix .. "No weapon found when trying to play: '" .. data.soundName .. "'")
			return
		end
		local soundToPlay = weapon.Grip:FindFirstChild(data.soundName)
		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		if not tool then
			return
		end
		if data.soundName == "Fire" then
			for _, child in ipairs(weapon:GetChildren()) do
				if child:IsA("Model") and child:FindFirstChild("Main") and child.Main:FindFirstChild("Fire") then
					soundToPlay = child.Main.Fire
					break
				end
			end
		end
		if soundToPlay then
			P.ReplicateSound.sendToList({ shooter = player, sound = soundToPlay }, U.playersAllExcept(U.asBlacklist(player)))
		end
	end)
	P.PlayCharacterSound.listen(function(data, player: Player?)
		if not player then
			return
		end
		if assets.Sounds:FindFirstChild(data.soundType) then
			P.ReplicateCharacterSound.sendToList({ shooter = player, soundType = data.soundType }, U.playersAllExcept(U.asBlacklist(player)))
		end
	end)
	P.FallDamage.listen(function(data, player: Player?)
		if not player then
			return
		end
		local damage = math.abs(data.damage)
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then
			if humanoid.Health <= damage then
				local killer = Instance.new("StringValue", player.Character)
				killer.Name = "Killer"
				killer.Value = "Falling"
			end
			player.Character.Humanoid:TakeDamage(damage)
			local fallSounds = assets.Sounds.FallDamage
			local newSound
			if damage <= 10 then
				newSound = fallSounds.Fall1
			elseif damage <= 30 then
				newSound = fallSounds.Fall2
			elseif damage <= 60 then
				newSound = fallSounds.Fall3
			else
				newSound = fallSounds.Fall4
			end
			newSound = newSound:Clone()
			newSound.PlaybackSpeed += math.random(-10, 10) / 100
			newSound.Parent = player.Character.PrimaryPart
			newSound:Play()
			debris:AddItem(newSound, newSound.TimeLength)
		end
	end)
	P.ReplicateFootstep.listen(function(data, player: Player?)
		if not player then
			return
		end
		local foot = data.foot
		if foot and foot:IsDescendantOf(player.Character) and player.Character then
			P.ReplicateFootstep.sendToList(
				{ material = data.material, foot = foot, volume = data.volume },
				U.playersInRangeExcept(U.asBlacklist(player), player.Character.HumanoidRootPart.Position, 100)
			)
		end
	end)
	P.RequestSuppression.listen(function(data, player: Player?)
		if not player then
			return
		end
		local target = data.target
		if typeof(target) ~= "Instance" or not target:IsA("Player") then
			return
		end
		P.ReportSuppression.sendToList(
			{ level = data.level, factor = data.factor, limit = data.limit },
			{ target }
		)
	end)
end

local function initializeWeaponEquip()
	if replicatedStorage:FindFirstChild("DD_GunsmithHandler") then
		replicatedStorage.DD_GunsmithHandler.ApplyAttachments.OnServerEvent:Connect(function(_player, weapon: Tool, attachments)
			local wepStats = WeaponStatLocator.getWeaponStats(weapon)
			wepStats.Attachments = attachments
		end)
	end
	net.packets.SwitchWeapon.listen(function(data, player: Player?)
		if not player then
			return
		end
		local tool = data.tool
		if player.Character and player.Character:FindFirstChild("WeaponRig") and player.Character.Humanoid.Health > 0 then
			local rig = player.Character.WeaponRig
			local curWeapon = player.Character.WeaponRig.Weapon:FindFirstChildWhichIsA("Model")
			local rigType = player.Character.Humanoid.RigType
			if rigType == Enum.HumanoidRigType.R6 then
				local torso = player.Character.Torso
				if curWeapon then
					torso["Left Shoulder"].Enabled = true
					torso["Right Shoulder"].Enabled = true
					rig.law.Enabled = false
					rig.raw.Enabled = false
					curWeapon:Destroy()
				end
				if player.Character.Humanoid.Health > 0 and tool and typeof(tool) == "Instance" then
					torso["Left Shoulder"].Enabled = false
					torso["Right Shoulder"].Enabled = false
					equipGun(player.Character.WeaponRig, tool, rigType)
				end
			else
				if curWeapon then
					player.Character["LeftUpperArm"]["LeftShoulder"].Enabled = true
					player.Character["LeftLowerArm"]["LeftElbow"].Enabled = true
					player.Character["LeftHand"]["LeftWrist"].Enabled = true
					player.Character["RightUpperArm"]["RightShoulder"].Enabled = true
					player.Character["RightLowerArm"]["RightElbow"].Enabled = true
					player.Character["RightHand"]["RightWrist"].Enabled = true
					for i = 1, #bodyparts do
						rig[bodyparts[i] .. "_w"].Enabled = false
					end
					curWeapon:Destroy()
				end
				if player.Character.Humanoid.Health > 0 and tool and typeof(tool) == "Instance" then
					player.Character["LeftUpperArm"]["LeftShoulder"].Enabled = false
					player.Character["LeftLowerArm"]["LeftElbow"].Enabled = false
					player.Character["LeftHand"]["LeftWrist"].Enabled = false
					player.Character["RightUpperArm"]["RightShoulder"].Enabled = false
					player.Character["RightLowerArm"]["RightElbow"].Enabled = false
					player.Character["RightHand"]["RightWrist"].Enabled = false
					equipGun(player.Character.WeaponRig, tool, rigType)
				end
			end
		end
	end)
end

local function initializeInteraction()
	proxPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "AmmoGiver" and prompt:FindFirstChild("SPH_PromptConfig") then
			local ammoTaken = false
			local promptConfig = prompt.SPH_PromptConfig
			local ammoPool = promptConfig.AmmoPool
			if ammoPool.Value < 1 and not promptConfig.InfAmmo.Value then
				return
			end
			local ammoType = promptConfig.AmmoType.Value
			local tools = player.Backpack:GetChildren()
			local equippedTool = player.Character:FindFirstChildWhichIsA("Tool")
			if equippedTool then
				table.insert(tools, equippedTool)
			end
			for _, tool in ipairs(tools) do
				if _collectionService:HasTag(tool, "SPH_Weapon") then
					local wepStats = WeaponStatLocator.getWeaponStats(tool)
					local arcadeAmmoPool = tool.Ammo.ArcadeAmmoPool
					if wepStats.infiniteAmmo then
						continue
					elseif arcadeAmmoPool.Value < arcadeAmmoPool.MaxValue and (wepStats.ammoType == ammoType or ammoType == "Universal") then
						ammoTaken = true
						local ammoNeeded = arcadeAmmoPool.MaxValue - arcadeAmmoPool.Value
						if ammoPool.Value > ammoNeeded then
							arcadeAmmoPool.Value = arcadeAmmoPool.MaxValue
							ammoPool.Value -= ammoNeeded
						else
							arcadeAmmoPool.Value += ammoPool.Value
							ammoPool.Value = 0
						end
						if ammoPool.Value <= 0 and config.despawnEmptyAmmoBoxes then
							prompt.Enabled = false
							task.delay(config.ammoBoxDespawnTime, function()
								if ammoPool.Value <= 0 then
									prompt.Parent.Parent:Destroy()
								end
							end)
						end
					elseif arcadeAmmoPool.Value <= 0 then
						break
					end
				end
			end
			if ammoTaken and prompt.Parent:FindFirstChild("Ammo") then
				prompt.Parent.Ammo:Play()
			end
		elseif prompt.Name == "GunGiver" and prompt:FindFirstChild("SPH_PromptConfig") then
			local promptCfg = prompt.SPH_PromptConfig
			local gunName = prompt:GetAttribute("ToolToGive") or prompt:FindFirstChildWhichIsA("Tool").Name
			local gunPool = promptCfg.GunPool
			if not promptCfg.AllowDupes.Value and (player.Character:FindFirstChild(gunName) or player.Backpack:FindFirstChild(gunName)) then
				return
			end
			if gunPool.Value > 0 or promptCfg.InfGuns.Value then
				local newGun = prompt:FindFirstChildWhichIsA("Tool") or Access.assets.ToolStorage:FindFirstChild(gunName)
				if not newGun then
					return
				else
					newGun = newGun:Clone()
				end
				newGun.Parent = player.Backpack
				gunPool.Value -= 1
				if gunPool.Value < 1 then
					prompt.Enabled = false
					local listener
					listener = gunPool.Changed:Connect(function()
						if gunPool.Value > 0 then
							listener:Disconnect()
							prompt.Enabled = true
						end
					end)
				end
				local gunModels = prompt.Parent.Parent:FindFirstChild("GunModels")
				if not promptCfg.InfGuns.Value and promptCfg.RemoveModels.Value and gunModels and #gunModels:GetChildren() > gunPool.Value then
					gunModels:GetChildren()[1]:Destroy()
				end
				if prompt.Parent:FindFirstChild("TakeGun") then
					prompt.Parent.TakeGun:Play()
				end
			end
		end
	end)
	net.packets.PlayerDropGun.listen(function(_data, player: Player?)
		if not player then
			return
		end
		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		if not config.gunDropping then
			return
		end
		if tool and _collectionService:HasTag(tool, "SPH_Weapon") then
			spawnGun(tool, player.Character.HumanoidRootPart.CFrame * dropCFrame, player)
		else
			return
		end
		local newSound = assets.Sounds.Misc.WeaponDrop:Clone()
		newSound.Parent = player.Character.HumanoidRootPart
		newSound:Play()
		newSound.PlayOnRemove = true
		newSound:Destroy()
	end)
	net.packets.PlayerToggleAttachment.listen(function(data, player: Player?)
		if not player then
			return
		end
		if not config.replicateAttachments then
			return
		end
		local attachmentType = data.attachmentType
		local toggle = data.enabled
		local weaponModel = player.Character.WeaponRig.Weapon:FindFirstChildWhichIsA("Model")
		if not weaponModel or not weaponModel:FindFirstChild("Grip") then
			return
		end
		local grip = weaponModel.Grip
		local P, U = net.packets, NetUtil
		if attachmentType == 0 and grip:FindFirstChild("Flashlight") then
			P.ReplicateToggleAttachment.sendToList({ attachment = grip.Flashlight, enabled = toggle, character = nil }, U.playersAllExcept(U.asBlacklist(player)))
		elseif attachmentType == 1 and grip:FindFirstChild("Laser") then
			P.ReplicateToggleAttachment.sendToList(
				{ attachment = grip.Laser, enabled = toggle, character = player.Character },
				U.playersAllExcept(U.asBlacklist(player))
			)
		end
		if attachmentType == 2 and grip:FindFirstChild("Bipod") then
			P.ReplicateToggleAttachment.sendToList(
				{ attachment = grip.Bipod, enabled = toggle, character = player.Character },
				U.playersAllExcept(U.asBlacklist(player))
			)
		end
		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		local wepStats
		if tool and _collectionService:HasTag(tool, "SPH_Weapon") then
			wepStats = WeaponStatLocator.getWeaponStats(tool)
		end
		if wepStats then
			for _, child in ipairs(weaponModel:GetChildren()) do
				if child:IsA("Model") and child:FindFirstChild("Main") then
					local main = child.Main
					if attachmentType == 0 then
						local flashlite = main:FindFirstChild("Flashlight")
						if flashlite then
							P.ReplicateToggleAttachment.sendToList(
								{ attachment = flashlite, enabled = toggle, character = nil },
								U.playersAllExcept(U.asBlacklist(player))
							)
						end
					elseif attachmentType == 1 then
						local laser = main:FindFirstChild("Laser")
						if laser then
							P.ReplicateToggleAttachment.sendToList(
								{ attachment = laser, enabled = toggle, character = player.Character },
								U.playersAllExcept(U.asBlacklist(player))
							)
						end
					elseif attachmentType == 2 then
						local bip = main:FindFirstChild("Bipod")
						if bip then
							P.ReplicateToggleAttachment.sendToList(
								{ attachment = bip, enabled = toggle, character = player.Character },
								U.playersAllExcept(U.asBlacklist(player))
							)
						end
					end
				end
			end
		end
	end)
	net.packets.MagGrab.listen(function(_data, player: Player?)
		if not player then
			return
		end
		if player.Character then
			local tool = player.Character:FindFirstChildWhichIsA("Tool")
			local humanoid = player.Character.Humanoid
			if not tool or not humanoid or humanoid.Health <= 0 then
				return
			end
			local weaponModel = player.Character.WeaponRig.Weapon:FindFirstChildWhichIsA("Model")
			local wepStats = WeaponStatLocator.getWeaponStats(tool)
			local magPart: BasePart = wepStats.projectile ~= "Bullet" and weaponModel[wepStats.projectile] or weaponModel:FindFirstChild("Mag")
			if magPart then
				local P, U = net.packets, NetUtil
				P.ReplicateMagGrab.sendToList({ magPart = magPart }, U.playersAllExcept(U.asBlacklist(player)))
			end
		end
	end)
end

initializeWeaponEquip()
initializePlayerLifecycle()
initializeCombat()
initializeAmmo()
initializeServerReplication()
initializeInteraction()

print(warnPrefix .. "Main Server loaded successfully!")
