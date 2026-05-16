-- Authoritative fire and bullet hit resolution.

local M = {}

local ctx

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = ReplicatedStorage.SPH_Framework
local HitContextTypes = require(Framework.Combat.HitContextTypes)
local VictimFinder = require(Framework.Combat.VictimFinder)

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
	local U, P = ctx.netUtil, ctx.net.packets
	P.ReplicateFire.sendToList(
		{ shooter = player, firePoint = firePoint },
		U.playersInRangeExcept(U.asBlacklist(player), point, dist)
	)
end

function M.Initialize(c)
	ctx = c

	local glassBreakFolder = ctx.assets.Sounds:FindFirstChild("GlassBreak")
	local glassBreakSounds = glassBreakFolder and glassBreakFolder:GetChildren() or {}

	VictimFinder.Initialize({
		dts = {
			atmod = ctx.atmod,
			useBulletForce = ctx.config.useBulletForce,
		},
		human = {
			leaderboard = ctx.config.leaderboard,
			leaderboardTKStat = ctx.config.leaderboardTKStat,
			leaderboardKillStat = ctx.config.leaderboardKillStat,
		},
		glass = {
			glassShatter = ctx.config.glassShatter,
			glassRespawnTime = ctx.config.glassRespawnTime,
			glassBreakSounds = glassBreakSounds,
		},
		bulletImpulse = {
			enabled = ctx.config.useBulletForce,
		},
	})

	ctx.net.packets.PlayerFire.listen(function(data, player)
		if not player then
			return
		end
		playerFire(player, data.firePoint)
	end)

	ctx.net.packets.BulletHit.listen(function(data, player)
		if not player then
			return
		end
		M.OnBulletHit(player, data.toolData, data.rayHit, data.bulletCFrame)
	end)
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

	local isExplosiveAmmunition = wepStats.explosiveAmmo

	if isExplosiveAmmunition then
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
	else
		local position = raycastResult.Position
		local U, P = ctx.netUtil, ctx.net.packets
		P.ReplicateHit.sendToList(
			{ toolData = tool, rayHit = raycastResult },
			U.playersInRangeExcept(U.asBlacklist(player), position, ctx.config.maxHitDistance)
		)
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

return M
