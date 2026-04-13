-- Lightweight server → client replication helpers (pose, sounds, footsteps).

local M = {}

local ctx

function M.Initialize(c)
	ctx = c

	ctx.bridges.bodyAnimRequest:Connect(function(player: Player, angle)
		local char = player.Character
		if char and (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")) and char.Humanoid.Health > 0 then
			char:SetAttribute("BodyRot", angle)
		end
	end)

	ctx.bridges.playerLean:Connect(function(player: Player, lean)
		local char = player.Character
		if char then
			char:SetAttribute("Lean", lean)
		end
	end)

	ctx.bridges.playSound:Connect(function(player: Player, soundName: string)
		local weapon = player.Character.WeaponRig.Weapon:FindFirstChildWhichIsA("Model")
		if not weapon then
			warn(ctx.warnPrefix .. "No weapon found when trying to play: '" .. soundName .. "'")
			return
		end
		local soundToPlay = weapon.Grip:FindFirstChild(soundName)

		local tool = player.Character:FindFirstChildWhichIsA("Tool")
		if not tool then
			return
		end

		if soundName == "Fire" then
			for _, child in ipairs(weapon:GetChildren()) do
				if child:IsA("Model") and child:FindFirstChild("Main") and child.Main:FindFirstChild("Fire") then
					soundToPlay = child.Main.Fire
					break
				end
			end
		end

		if soundToPlay then
			ctx.bridges.repSound:FireToAllExcept(player, player, soundToPlay)
		end
	end)

	ctx.bridges.playCharSound:Connect(function(player, soundType)
		if ctx.assets.Sounds:FindFirstChild(soundType) then
			ctx.bridges.repCharSound:FireToAllExcept(player, player, soundType)
		end
	end)

	ctx.bridges.fallDamage:Connect(function(player, damage)
		damage = math.abs(damage)
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then
			if humanoid.Health <= damage then
				local killer = Instance.new("StringValue", player.Character)
				killer.Name = "Killer"
				killer.Value = "Falling"
			end
			player.Character.Humanoid:TakeDamage(damage)
			local fallSounds = ctx.assets.Sounds.FallDamage
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
			ctx.debris:AddItem(newSound, newSound.TimeLength)
		end
	end)

	ctx.bridges.repFootstep:Connect(function(player, material, foot: Sound, volume)
		if foot and foot:IsDescendantOf(player.Character) and player.Character then
			ctx.bridges.repFootstep:FireAllInRangeExcept(player, player.Character.HumanoidRootPart.Position, 100, material, foot, volume)
		end
	end)
end

return M
