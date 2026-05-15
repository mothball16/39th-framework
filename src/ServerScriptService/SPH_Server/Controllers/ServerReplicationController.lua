-- Lightweight server → client replication helpers (pose, sounds, footsteps).

local M = {}

local ctx

function M.Initialize(c)
	ctx = c

	local P, U = ctx.net.packets, ctx.netUtil

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
			warn(ctx.warnPrefix .. "No weapon found when trying to play: '" .. data.soundName .. "'")
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
		if ctx.assets.Sounds:FindFirstChild(data.soundType) then
			P.ReplicateCharacterSound.sendToList(
				{ shooter = player, soundType = data.soundType },
				U.playersAllExcept(U.asBlacklist(player))
			)
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
end

return M
