-- Authoritative fire and bullet hit resolution.

local M = {}

local ctx

local function checkNaughtyList(playerID)
	if table.find(ctx.naughtyList, playerID) then
		return true
	end
end

local function isGunLoaded(tool)
	local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
	local gunAmmo = tool.Ammo
	local magAmmo = gunAmmo.MagAmmo
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

local function playerFire(player: Player, firePoint: CFrame)
	local tool = player.Character:FindFirstChildWhichIsA("Tool")
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

	local point = player.Character.HumanoidRootPart.Position
	local dist = ctx.config.fireEffectDistance
	ctx.bridges.repFire:FireAllInRangeExcept(player, point, dist, player, firePoint)
end

function M.Initialize(c)
	ctx = c

	ctx.bridges.playerFire:Connect(playerFire)

	ctx.bridges.bulletHit:Connect(function(player: Player, tool: Tool, raycastResult: RaycastResult, bulletCFrame: CFrame)
		if ctx.config.ammoCountCheck then
			if player:GetAttribute("LastFiredGun") then
				local lastFiredGun = player:GetAttribute("LastFiredGun")
				local lastFiredMagCount = player:GetAttribute("LastFiredMagCount")
				local actualTool = typeof(tool) == "table" and tool.Tool or tool
				if player.Character:FindFirstChild(lastFiredGun) and lastFiredMagCount == actualTool.Ammo.MagAmmo.Value then
					return
				end
			end

			local actualTool = typeof(tool) == "table" and tool.Tool or tool
			player:SetAttribute("LastFiredGun", actualTool.Name)
			player:SetAttribute("LastFiredMagCount", actualTool.Ammo.MagAmmo.Value)
		end

		if player and checkNaughtyList(player.UserId) then
			return
		end
		if not tool then
			return
		elseif tool and typeof(tool) ~= "Instance" and typeof(tool) ~= "table" then
			warn(ctx.warnPrefix .. player.Name .. " attempted to call bulletHit without a tool.")
			return
		end

		local actualTool = tool
		if typeof(tool) == "table" and tool.Tool then
			actualTool = tool.Tool
		end

		if ctx.config.requireEquippedGun and actualTool.Parent ~= player.Character then
			if ctx.config.strikes then
				player:SetAttribute("Strikes", player:GetAttribute("Strikes") + 1)
				player:SetAttribute("LastStrikeReason", "Attempting to deal damage with no tool equipped")
			end
			return
		elseif actualTool.Parent ~= player.Character and actualTool.Parent ~= player.Backpack then
			return
		end

		local wepStats
		if typeof(tool) == "table" then
			if tool.model then
				wepStats = require(tool.model.Parent.TurretModule).guns[tool.index]
			else
				wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.Tool.SPH_Weapon)
				if tool.fireMode == 4 and wepStats.hasUBGL then
					wepStats = wepStats.getStatsForMode(4)
				end
			end
		elseif tool:IsA("Tool") then
			wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
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

					if vehicle and hitPart:HasTag("Dragoon_Armor") and not table.find(vehiclesHit, vehicle) then
						local result = workspace:Raycast(originPos + Vector3.new(0, 1, 0), (vehicle.PrimaryPart.Position - originPos).Unit * expRadius, ctx.explosionRayParams)
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

		local hitPart: BasePart = raycastResult.Instance
		if not hitPart or not hitPart.Parent then
			return
		end
		local humanoid: Humanoid = hitPart.Parent:FindFirstChildWhichIsA("Humanoid")
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
			local damage = wepStats.damage[hitPart.Name] or wepStats.damage.Other

			if hitPart.Name == "HumanoidRootPart" then
				damage = wepStats.damage.UpperTorso or wepStats.damage.Torso
			end

			if humanoid.Health > 0 and humanoid.Health - damage <= 0 then
				if ctx.config.leaderboard and (player.Name ~= humanoid.Parent.Name) then
					local victimPlayer = game.Players:GetPlayerFromCharacter(humanoid.Parent)
					if victimPlayer and victimPlayer.Team == player.Team then
						player.leaderstats[ctx.config.leaderboardTKStat].Value += 1
					elseif victimPlayer then
						player.leaderstats[ctx.config.leaderboardKillStat].Value += 1
					end
				end
				local killer = Instance.new("ObjectValue", humanoid.Parent)
				killer.Name = "Killer"
				killer.Value = player

				if ctx.config.printKillLogs and player and otherPlayer then
					print(ctx.warnPrefix .. " " .. player.Name .. " killed " .. otherPlayer.Name)
				end

				if ctx.config.listenForKillAll then
					if player:GetAttribute("LastKillTime") then
						local lastTime = player:GetAttribute("LastKillTime")
						if time() - lastTime <= 0.1 then
							player:SetAttribute("MultiKill", (player:GetAttribute("MultiKill") or 0) + 1)
							if player:GetAttribute("MultiKill") > ctx.config.multiKillThreshold then
								table.insert(ctx.naughtyList, player.UserId)
								player:Kick("Disconnected")
								warn(ctx.warnPrefix .. player.Name .. " was kicked for killing too quickly!")
								return
							end
						else
							player:SetAttribute("MultiKill", 0)
						end
						if ctx.config.multiKillDistanceCheck and time() - lastTime < 3 and (humanoid.Parent.WorldPivot.Position - player:GetAttribute("LastKillPosition")).Magnitude > 100 then
							warn(ctx.warnPrefix .. player.Name .. " attempted to kill two players >100 studs apart!")

							if ctx.config.strikes then
								player:SetAttribute("Strikes", player:GetAttribute("Strikes") + 1)
								player:SetAttribute("LastStrikeReason", "Attempting to kill multiple players >100 studs apart")
							end

							return
						end
					end

					player:SetAttribute("LastKillTime", time())
					player:SetAttribute("LastKillPosition", humanoid.Parent.WorldPivot.Position)
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

			local tempPart = hitPart:Clone()
			tempPart.Name = "TempGlass"
			tempPart.Parent = workspace

			local prevTransparency = hitPart.Transparency
			local prevCanCollide = hitPart.CanCollide
			local prevCanQuery = hitPart.CanQuery
			local prevCanTouch = hitPart.CanTouch

			hitPart.Transparency = 1
			hitPart.CanCollide = false
			hitPart.CanQuery = false
			hitPart.CanTouch = false

			delay(ctx.config.glassRespawnTime, function()
				if hitPart and hitPart.Parent then
					hitPart.Transparency = prevTransparency
					hitPart.CanCollide = prevCanCollide
					hitPart.CanQuery = prevCanQuery
					hitPart.CanTouch = prevCanTouch
				end
			end)

			if hitPart:IsA("Part") and hitPart.Shape == Enum.PartType.Block or hitPart:IsA("WedgePart") then
				ctx.fractureGlass(tempPart, hitPosition, bulletCFrame.LookVector * 10)
			else
				tempPart:Destroy()
			end

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
			if not otherPlayer or humanoid.Health <= 0 then
				hitPart:SetNetworkOwner(player)
			end
		end
	end)
end

return M
