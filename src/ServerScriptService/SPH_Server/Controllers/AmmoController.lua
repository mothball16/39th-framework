-- Reload, chamber, bolt, fire mode, bolt replication.

local M = {}

local ctx

function M.Initialize(c)
	ctx = c

	ctx.bridges.repReload:Connect(function(player: Player)
		if ctx.config.listenForReloadSpam then
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

		local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)
		local magAmmo = tool.Ammo.MagAmmo
		local arcadeAmmoPool = tool.Ammo.ArcadeAmmoPool

		local currentFireMode = tool.FireMode.Value

		if currentFireMode == 4 and wepStats.hasUBGL then
			local ubglAmmo = tool:FindFirstChild("UBGLAmmo")
			local ubglAmmoPool = tool:FindFirstChild("UBGLAmmoPool")

			if ubglAmmo and ubglAmmoPool then
				if ubglAmmo.Value < 1 then
					if ubglAmmoPool.Value > 0 then
						ubglAmmo.Value = 1
						ubglAmmoPool.Value = ubglAmmoPool.Value - 1
						print("UBGL reloaded! Loaded ammo: " .. ubglAmmo.Value .. ", Pool remaining: " .. ubglAmmoPool.Value)
					else
						print("UBGL reload failed - no grenades remaining in pool")
					end
				else
					print(
						"UBGL reload attempted but already loaded. Current ammo: "
							.. ubglAmmo.Value
							.. ", Pool: "
							.. ubglAmmoPool.Value
					)
				end
			end
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
				local clipSize = (wepStats.clipSize or wepStats.magazineCapacity)
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
				local clipSize = (wepStats.clipSize or wepStats.magazineCapacity)

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

	ctx.bridges.repChamber:Connect(function(player: Player)
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

	ctx.bridges.repBoltOpen:Connect(function(player: Player)
		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		if tool and tool.Parent == player.Character then
			tool.BoltReady.Value = false
			if tool:FindFirstChild("Chambered") then
				tool.Chambered.Value = false
			end
		end
	end)

	ctx.bridges.switchFireMode:Connect(function(player: Player, newFireMode)
		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		if tool and tool:FindFirstChild("SPH_Weapon") then
			local wepStats = ctx.WeaponStatLocator.getWeaponStats(tool.SPH_Weapon)

			if newFireMode == 4 and not wepStats.hasUBGL then
				return
			end

			tool.FireMode.Value = newFireMode
		end
	end)

	ctx.bridges.moveBolt:Connect(function(player, direction, magAmmo)
		local playerPosition = player.Character.HumanoidRootPart.Position
		ctx.bridges.repBolt:FireAllInRangeExcept(player, playerPosition, ctx.config.fireEffectDistance, player, direction, magAmmo)
	end)
end

return M
