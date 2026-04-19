-- Authoritative fire and bullet hit resolution.

local M = {}

local ctx

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sph = require(ReplicatedStorage.SPH_Framework.Core.GameAccess)
local DamageLogic = require(sph.framework.Combat.DamageLogic)

local function checkNaughtyList(playerID)
	if table.find(ctx.naughtyList, playerID) then
		return true
	end
	return false
end

local function isGunLoaded(tool)
	local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
	local gunAmmo = tool.Ammo
	return not wepStats.openBolt and tool.Chambered.Value or wepStats.openBolt and gunAmmo.MagAmmo.Value > 0
end

local function teamKillCheck(player1: Player, player2: Player)
	if not ctx.config.teamKill and not player1.Neutral and not player2.Neutral then
		if player1.Team == player2.Team then
			return false
		end
	end
	return true
end

-- Bridge sends either a Tool or a small table (UBGL / turret / etc.).
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
		local stats = ctx.WeaponStatLocator.getWeaponStats(tool.Tool.SPH_Weapon)
		if tool.fireMode == 4 and stats.hasUBGL then
			stats = stats.getStatsForMode(4)
		end
		return stats
	end
	if tool:IsA("Tool") then
		return ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
	end
	return nil
end

local function playerFire(player: Player, firePoint: CFrame)
	local tool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
	if not tool or not tool:IsA("Tool") then
		warn(ctx.warnPrefix .. "PlayerFire Canceled: No tool was found.")
		return
	end
	local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
	local gunAmmo = tool.Ammo
	local magAmmo = gunAmmo.MagAmmo

	local currentFireMode = tool.FireMode.Value

	if currentFireMode == 4 and wepStats.hasUBGL then
		local ubglAmmo = tool:FindFirstChild("UBGLAmmo")
		if not ubglAmmo or ubglAmmo.Value <= 0 then
			return
		end

		ubglAmmo.Value = ubglAmmo.Value - 1

		tool.BoltReady.Value = true
	elseif currentFireMode == 5 then
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
	local dist = ctx.config.fireEffectDistance
	ctx.bridges.repFire:FireAllInRangeExcept(player, point, dist, player, firePoint)
end

function M.Initialize(c)
	ctx = c

	ctx.bridges.playerFire:Connect(playerFire)

	ctx.bridges.bulletHit:Connect(M.OnBulletHit)
end

function M.OnBulletHit(player: Player, tool: Tool, raycastResult: RaycastResult, bulletCFrame: CFrame)
	if not tool then
		return
	end
	if typeof(tool) ~= "Instance" and typeof(tool) ~= "table" then
		warn(ctx.warnPrefix .. player.Name .. " attempted to call bulletHit without a tool.")
		return
	end

	local equippedTool = equippedToolFromBridge(tool)

	if ctx.config.ammoCountCheck then
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

	if ctx.config.requireEquippedGun and equippedTool.Parent ~= player.Character then
		if ctx.config.strikes then
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

	local kaboom = wepStats.explosiveAmmo

	if kaboom then
		local expRadius = wepStats.explosionRadius
		local expEffect = wepStats.explosionEffect

		if ctx.atmod then
			local expDmg = math.abs(math.random(wepStats.ATDefaultDamage[1], wepStats.ATDefaultDamage[2]))
			local expPen = math.abs(math.random(wepStats.ATDefaultPen[1], wepStats.ATDefaultPen[2]))

			local vehiclesHit = {}
			local propsHit = {}

			local originPos = raycastResult.Position
			local partsInRange = workspace:GetPartBoundsInRadius(originPos, expRadius * 2, ctx.explosionOverlapParams)

			for _, hitPart in ipairs(partsInRange) do
				local dist = (originPos - hitPart.Position).Magnitude
				local AOE_Dmg = math.abs((1 - math.map(dist, 0, expRadius * 2, 0, 1)) * expDmg)
				local AOE_Pen = expPen * 0.5
				local AOE_PlrDmg = math.abs(expRadius / 1.5 / dist * 100)
				local AOE_ShellForce = (1 - math.map(dist, 0, expRadius * 2, 0, 1)) * wepStats.bulletForce
				local AOE_Knockback = (ctx.config.useBulletForce and (originPos - hitPart.Position).Unit * -AOE_ShellForce) or nil

				local vehicle: Model = ctx.atmod.TagCheck(hitPart, "Vehicles")
				local prop: Model = ctx.atmod.TagCheck(hitPart, "Props")

				local vehiclePrimary = vehicle and vehicle.PrimaryPart
				if vehicle and vehiclePrimary and hitPart:HasTag("Dragoon_Armor") and not table.find(vehiclesHit, vehicle) then
					local result = workspace:Raycast(originPos + Vector3.new(0, 1, 0), (vehiclePrimary.Position - originPos).Unit * expRadius, ctx.explosionRayParams)
					if not ctx.config.explosionRaycast or (result and result.Instance and result.Instance:IsDescendantOf(vehicle)) then
						table.insert(vehiclesHit, vehicle)
						ctx.atmod.DamageVehicle(player, hitPart, AOE_Pen, AOE_Dmg, AOE_Knockback, false)
					end
					ctx.atmod.DamageMisc(player, hitPart, hitPart.Position, originPos, AOE_Pen, AOE_Dmg, AOE_PlrDmg, nil, false)
				elseif not vehicle then
					ctx.atmod.DamageMisc(player, hitPart, hitPart.Position, originPos, AOE_Pen, AOE_Dmg, AOE_PlrDmg, AOE_Knockback, false)
				end
				if prop and not table.find(propsHit, prop) then
					local result = workspace:Raycast(originPos + Vector3.new(0, 1, 0), (prop.WorldPivot.Position - originPos).Unit * expRadius, ctx.explosionRayParams)
					if not ctx.config.explosionRaycast or (result and result.Instance and result.Instance:IsDescendantOf(prop)) then
						table.insert(propsHit, prop)
						ctx.atmod.DamageProp(player, hitPart, AOE_Pen, AOE_Dmg, AOE_Knockback, false)
					end
				end
			end
		end

		ctx.explosionMod(raycastResult.Position, expRadius, expEffect, player)

		if ctx.config.listenForExplosionSpam then
			local lastExplosion = player:GetAttribute("LastExplosion")
			if lastExplosion and time() - lastExplosion <= 0.3 then
				table.insert(ctx.naughtyList, player.UserId)
				player:Kick("Disconnected")
				warn(ctx.warnPrefix .. player.Name .. " was kicked for trying to create multiple explosions at once!")
				return
			end
			player:SetAttribute("LastExplosion", time())
		end
	else
		local position = raycastResult.Position
		ctx.bridges.repHit:FireAllInRangeExcept(player, position, ctx.config.maxHitDistance, tool, raycastResult)
	end

	local hitInst = raycastResult.Instance
	if not hitInst or not hitInst:IsA("BasePart") or not hitInst.Parent then
		return
	end
	local hitPart = hitInst :: BasePart
	local humanoid = hitPart.Parent:FindFirstChildWhichIsA("Humanoid")
	local otherPlayer
	if humanoid then
		otherPlayer = ctx.players:GetPlayerFromCharacter(humanoid.Parent)
	end

	if ctx.atmod and wepStats.ATCanDamage then
		local pen = math.random(wepStats.ATDefaultPen[1], wepStats.ATDefaultPen[2])
		local dmg = math.random(wepStats.ATDefaultDamage[1], wepStats.ATDefaultDamage[2])
		local knockback = (ctx.config.useBulletForce and Vector3.new(0, 0, -(wepStats.bulletForce or 0))) or nil
		if hitPart and hitPart:HasTag("Dragoon_Armor") then
			ctx.atmod.DamageVehicle(player, hitPart, pen, dmg, knockback, true)
		elseif not hitPart:HasTag("Dragoon_Armor") and not hitPart:HasTag("PropSystem_Armor") then
			ctx.atmod.DamageMisc(player, hitPart, hitPart.Position, nil, pen, dmg, dmg, knockback, true)
		elseif hitPart:HasTag("PropSystem_Armor") then
			ctx.atmod.DamageProp(player, hitPart, pen, dmg, knockback, true)
		end
	end

	if humanoid and humanoid.Health > 0 and ((otherPlayer and teamKillCheck(player, otherPlayer)) or not otherPlayer) then
		local ray = raycastResult :: any
		local dist = (typeof(ray.Position) == "Vector3" and typeof(ray.Origin) == "Vector3") and (ray.Position - ray.Origin).Magnitude or nil
		local damage = DamageLogic.getDamage(wepStats.damage, hitPart.Name, dist, wepStats.range)

		if humanoid.Health > 0 and humanoid.Health - damage <= 0 then
			if ctx.config.leaderboard and (player.Name ~= humanoid.Parent.Name) then
				local victimPlayer = game.Players:GetPlayerFromCharacter(humanoid.Parent)
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats and victimPlayer and victimPlayer.Team == player.Team then
					local tkStat = leaderstats:FindFirstChild(ctx.config.leaderboardTKStat)
					if tkStat and tkStat:IsA("IntValue") then
						tkStat.Value += 1
					end
				elseif leaderstats and victimPlayer then
					local killStat = leaderstats:FindFirstChild(ctx.config.leaderboardKillStat)
					if killStat and killStat:IsA("IntValue") then
						killStat.Value += 1
					end
				end
			end
			local killer = Instance.new("ObjectValue", humanoid.Parent)
			killer.Name = "Killer"
			killer.Value = player

			if ctx.config.printKillLogs and player and otherPlayer then
				print(ctx.warnPrefix .. " " .. player.Name .. " killed " .. otherPlayer.Name)
			end

			if ctx.config.listenForKillAll then
				local lastKillTime = tonumber(player:GetAttribute("LastKillTime"))
				if lastKillTime then
					local lastTime = lastKillTime
					if time() - lastTime <= 0.1 then
						local multiKill = (tonumber(player:GetAttribute("MultiKill")) or 0) + 1
						player:SetAttribute("MultiKill", multiKill)
						if multiKill > ctx.config.multiKillThreshold then
							table.insert(ctx.naughtyList, player.UserId)
							player:Kick("Disconnected")
							warn(ctx.warnPrefix .. player.Name .. " was kicked for killing too quickly!")
							return
						end
					else
						player:SetAttribute("MultiKill", 0)
					end
					local victimChar = humanoid.Parent :: Model
					local lastKillPos = player:GetAttribute("LastKillPosition")
					local lastKillVec = typeof(lastKillPos) == "Vector3" and (lastKillPos :: Vector3) or nil
					if
						ctx.config.multiKillDistanceCheck
						and lastKillVec
						and time() - lastTime < 3
						and (victimChar.WorldPivot.Position - lastKillVec).Magnitude > 100
					then
						warn(ctx.warnPrefix .. player.Name .. " attempted to kill two players >100 studs apart!")

						if ctx.config.strikes then
							player:SetAttribute("Strikes", (tonumber(player:GetAttribute("Strikes")) or 0) + 1)
							player:SetAttribute("LastStrikeReason", "Attempting to kill multiple players >100 studs apart")
						end

						return
					end
				end

				player:SetAttribute("LastKillTime", time())
				player:SetAttribute("LastKillPosition", (humanoid.Parent :: Model).WorldPivot.Position)
			end
		end

		local creator = Instance.new("ObjectValue")
		creator.Name = "creator"
		creator.Value = player
		creator.Parent = humanoid
		ctx.debris:AddItem(creator, 0.5)

		humanoid:TakeDamage(damage)
	elseif (hitPart.Name == "Glass" or ctx.collectionService:HasTag(hitPart, "BreakableGlass")) and ctx.config.glassShatter then
		local hitPosition = raycastResult.Position

		--[[
		local tempPart = hitPart:Clone()
		tempPart.Name = "TempGlass"
		tempPart.Parent = workspace]]

		local prevTransparency = hitPart.Transparency
		local prevCanCollide = hitPart.CanCollide
		local prevCanQuery = hitPart.CanQuery
		local prevCanTouch = hitPart.CanTouch

		hitPart.Transparency = 1
		hitPart.CanCollide = false
		hitPart.CanQuery = false
		hitPart.CanTouch = false

		task.delay(ctx.config.glassRespawnTime, function()
			if hitPart and hitPart.Parent then
				hitPart.Transparency = prevTransparency
				hitPart.CanCollide = prevCanCollide
				hitPart.CanQuery = prevCanQuery
				hitPart.CanTouch = prevCanTouch
			end
		end)

		--[[
		if hitPart:IsA("Part") and hitPart.Shape == Enum.PartType.Block or hitPart:IsA("WedgePart") then
			ctx.fractureGlass(tempPart, hitPosition, bulletCFrame.LookVector * 10)
		else
			tempPart:Destroy()
		end]]

		local soundAtt = Instance.new("Attachment", workspace.Terrain)
		soundAtt.WorldPosition = hitPosition
		local shatterSound = ctx.assets.Sounds.GlassBreak:GetChildren()[math.random(#ctx.assets.Sounds.GlassBreak:GetChildren())]:Clone()
		shatterSound.Parent = soundAtt
		shatterSound:Play()
		ctx.debris:AddItem(soundAtt, shatterSound.TimeLength)
	elseif not hitPart.Anchored and ctx.config.useBulletForce and not humanoid then
		local tempAtt = Instance.new("Attachment", hitPart)
		tempAtt.WorldCFrame = CFrame.new(raycastResult.Position) * (bulletCFrame - bulletCFrame.Position)
		local force = Instance.new("VectorForce", tempAtt)
		force.Attachment0 = tempAtt
		local buFo = wepStats.bulletForce
		force.Force = Vector3.new(0, 0, -buFo)
		ctx.debris:AddItem(tempAtt, 0.1)
		if not otherPlayer then
			hitPart:SetNetworkOwner(player)
		end
	end
end

return M
