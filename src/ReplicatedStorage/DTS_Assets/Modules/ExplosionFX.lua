local Debris = game:GetService("Debris")
local players = game:GetService("Players")

local explosionRayParams = RaycastParams.new()
explosionRayParams.IgnoreWater = true
explosionRayParams.RespectCanCollide = true

local explosionSounds = {287390459, 287390954, 287391087, 287391197, 287391361, 287391499, 287391567, 8226406520}
local explosionRadius = 30 --How big is a default explosion?

local function Explode(explosionOrigin:Vector3, blastRadius:number, explosionType:string)
	local effects = script:FindFirstChild(explosionType or "Default")
	local blastMult = math.clamp(blastRadius/explosionRadius, 0, 1)
	
	if effects then
		local removeTime = 5
		local explosion = Instance.new("Attachment",workspace.Terrain)
		explosion.Name = "Explosion"
		explosion.WorldPosition = explosionOrigin
		
		--print(effects)
		--VFX
		for _, effect in effects:GetChildren() do
			local newEffect = effect:Clone()
			newEffect.Parent = explosion
			if newEffect:IsA("ParticleEmitter") then
				newEffect.Lifetime = NumberRange.new(newEffect.Lifetime.Min * blastMult, newEffect.Lifetime.Max * blastMult)
				
				if newEffect:FindFirstChild("Count") then
					newEffect:Emit( math.ceil(newEffect.Count.Value*blastMult))
				else
					newEffect:Emit(1)
				end
				if newEffect.Lifetime.Max > removeTime then
					removeTime = newEffect.Lifetime.Max
				end
			elseif newEffect:IsA("Light") then
				newEffect.Enabled = true
				Debris:AddItem(newEffect,0.1)
			end
		end
		
		--Sound
		local explosionSound = Instance.new("Sound",explosion)
		explosionSound.SoundId = "rbxassetid://"..explosionSounds[math.random(#explosionSounds)]
		explosionSound.Volume = 3
		explosionSound.RollOffMode = Enum.RollOffMode.InverseTapered
		explosionSound.RollOffMaxDistance = 10000
		explosionSound.PlayOnRemove = true
		explosionSound:Destroy()
			
		-- Destroy after removeTime
		Debris:AddItem(explosion, removeTime)
	end
end

return Explode
