local debris = game:GetService("Debris")
local players = game:GetService("Players")

local sph = require(script.Parent.Parent.GameAccess)
local config = sph.config

local explosionOverlapParams = OverlapParams.new()
explosionOverlapParams.MaxParts = 500
explosionOverlapParams.RespectCanCollide = true

local explosionRayParams = RaycastParams.new()
explosionRayParams.IgnoreWater = true
explosionRayParams.RespectCanCollide = true

local explosionSounds = {287390459, 287390954, 287391087, 287391197, 287391361, 287391499, 287391567, 8226406520}

local dts = game.ReplicatedStorage:FindFirstChild("DTS_Assets") -- DD_SPH: Checks if DTS is present
local sph = require(game.ReplicatedStorage.SPH_Framework.GameAccess)
local effectsFolder = sph.assets.Effects.Explosions

local function Explode(explosionOrigin:Vector3, blastRadius:number, explosionType:string, attackingPlayer:Player) -- DD_SPH: Check which player issued this explosion
	local effects = effectsFolder:FindFirstChild(explosionType)
	if effects then
		local removeTime = 10
		effects = effects:GetChildren()
		local explosion = Instance.new("Attachment",workspace.Terrain)
		explosion.Name = "Explosion"
		explosion.WorldPosition = explosionOrigin

		-- VFX
		for _, effect in ipairs(effects) do
			local newEffect = effect:Clone()
			newEffect.Parent = explosion
			if newEffect:IsA("ParticleEmitter") then
				if newEffect:FindFirstChild("Count") then
					newEffect:Emit(newEffect.Count.Value)
				else
					newEffect:Emit(1)
				end
				if newEffect.Lifetime.Max > removeTime then
					removeTime = newEffect.Lifetime.Max
				end
			elseif newEffect:IsA("Light") then
				newEffect.Enabled = true
				debris:AddItem(newEffect,0.1)
			end
		end

		-- Sound
		local explosionSound = Instance.new("Sound",explosion)
		explosionSound.SoundId = "rbxassetid://"..explosionSounds[math.random(#explosionSounds)]
		explosionSound.Volume = 4
		explosionSound.RollOffMode = Enum.RollOffMode.InverseTapered
		explosionSound.RollOffMaxDistance = 10000
		explosionSound.PlayOnRemove = true
		explosionSound:Destroy()

		-- Damage
		local humanoidsHit = {}
		local partsInRange = workspace:GetPartBoundsInRadius(explosionOrigin, blastRadius * 2, explosionOverlapParams)

		for _, hitPart in ipairs(partsInRange) do -- Loop through all parts found in range
			local humanoid = hitPart.Parent:FindFirstChild("Humanoid")
			local hrp = hitPart.Parent:FindFirstChild("HumanoidRootPart")
			if hrp and humanoid and not table.find(humanoidsHit,humanoid) then -- If a humanoid was hit and hasn't been hit yet
				local result = workspace:Raycast(explosionOrigin + Vector3.new(0,1,0), (hrp.Position - explosionOrigin).Unit * blastRadius,explosionRayParams)
				if not config.explosionRaycast or (result and result.Instance and result.Instance:IsDescendantOf(humanoid.Parent)) then
					table.insert(humanoidsHit,humanoid)
					local dist = (explosionOrigin - hitPart.Position).Magnitude
					--humanoid:TakeDamage(blastRadius / 1.5 / dist * 100) -- Deal damage based on range, kill if too close

					-- DD_SPH: Explosions count as kills for the player aand TK can be prevented
					local victimPlayer = game.Players:GetPlayerFromCharacter(humanoid.Parent)
					if victimPlayer and victimPlayer.Team ~= attackingPlayer.Team or (victimPlayer.Team == attackingPlayer.Team and config.teamKill) then
						local canDamage = true -- DD_SPH: Doesn't allow damage if the player is seated and a DTS installation is present
						
						if dts then
							if humanoid.Sit then
								canDamage = false
							end
						end

						if canDamage then
							humanoid:TakeDamage(blastRadius / 1.5 / dist * 100) -- Deal damage based on range, kill if too close
						end
					end
					-- This should work with most roblox leaderboards
					if humanoid.Health <= 0 then
						if config.leaderboard and (attackingPlayer.Name ~= humanoid.Parent.Name) then
							if victimPlayer and victimPlayer.Team == attackingPlayer.Team then
								attackingPlayer.leaderstats[config.leaderboardTKStat].Value += 1 
							elseif victimPlayer then
								attackingPlayer.leaderstats[config.leaderboardKillStat].Value += 1 
							end
						end

						local killer = Instance.new("ObjectValue",humanoid.Parent)
						killer.Name = "Killer"
						killer.Value = attackingPlayer

						-- This should work with most roblox leaderboards
						local creator = Instance.new("ObjectValue")
						creator.Name = "creator"
						creator.Value = attackingPlayer
						creator.Parent = humanoid
					end
					-- </DD_SPH>
				end
			end
			if not hitPart.Anchored then -- Apply a force to unanchored parts
				local tempAtt = Instance.new("Attachment",hitPart)
				tempAtt.Name = "ExplosionForce"
				local force = Instance.new("VectorForce",tempAtt)
				force.Attachment0 = tempAtt
				force.Force = (explosionOrigin - hitPart.Position).Unit * -2000
				debris:AddItem(tempAtt,0.1)
			end
		end

		-- Destroy after removeTime
		debris:AddItem(explosion, removeTime)
	end
end

return Explode
