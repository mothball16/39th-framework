local Debris = game:GetService("Debris")

-- Impact sounds
local Glass = {"1565824613"; "1565825075";}
local Metal = {"282954522"; "282954538"; "282954576"; "1565756607"; "1565756818";}
local Grass = {"1565830611"; "1565831129"; "1565831468"; "1565832329";}
local Wood = {"287772625"; "287772674"; "287772718"; "287772829"; "287772902";}
local Concrete = {"287769261"; "287769348"; "287769415"; "287769483"; "287769538";}
local Hits = {"363818432"; "363818488"; "363818567"; "363818611"; "363818653";}
local Headshots = {"4459572527"; "4459573786";"3739364168";}

local Effects = script.Parent.Parent.FX

local Hitmarker = {}

function CheckColor(Color,Add)
	Color = Color + Add
	if Color > 1 then
		Color = 1
	elseif Color < 0 then
		Color = 0
	end
	return Color
end

function CreateEffect(Type,Attachment,ColorAdjust,HitPart, Class)
	local fxFolder = Effects:FindFirstChild(Class)
	if not fxFolder then fxFolder = Effects.Hit_Light end

	local NewType
	if fxFolder:FindFirstChild(Type) then
		NewType = fxFolder:FindFirstChild(Type)
	else
		NewType = fxFolder.Stone -- Default to Stone/Concrete
	end
	local NewEffect = NewType:GetChildren()[math.random(1,#NewType:GetChildren())]:Clone()
	local MaxTime = 3 -- Placeholder for max time of total effect
	for _, Effect in pairs(NewEffect:GetChildren()) do
		if not Effect:IsA("ParticleEmitter") then return end

		Effect.Parent = Attachment
		Effect.Enabled = false

		if ColorAdjust and HitPart then
			local NewColor = HitPart.Color
			local Add = 0.3
			if HitPart.Material == Enum.Material.Fabric then
				Add = -0.2 -- Darker
			end

			NewColor = Color3.new(CheckColor(NewColor.R, Add),CheckColor(NewColor.G, Add),CheckColor(NewColor.B, Add)) -- Adjust new color

			Effect.Color = ColorSequence.new({ -- Set effect color
				ColorSequenceKeypoint.new(0,NewColor),
				ColorSequenceKeypoint.new(1,NewColor)
			})
		end

		if Effect.Rate > 10 then
			Effect:Emit(Effect.Rate / 10) -- Calculate how many particles emit based on rate
		else
			Effect:Emit(1)
		end
		if Effect.Lifetime.Max > MaxTime then
			MaxTime = Effect.Lifetime.Max
		end
	end
	local HitSound = Instance.new("Sound")
	local SoundType -- Convert Type to equivalent sound table
	if Type == "Headshot" then
		SoundType = Headshots
	elseif Type == "Hit" then
		SoundType = Hits
	elseif Type == "Glass" then
		SoundType = Glass
	elseif Type == "Metal" then
		SoundType = Metal
	elseif Type == "Ground" then
		SoundType = Grass
	elseif Type == "Wood" then
		SoundType = Wood
	elseif Type == "Stone" then
		SoundType = Concrete
	else
		SoundType = Concrete -- Default to Stone/Concrete
	end
	HitSound.Parent = Attachment
	HitSound.Volume = math.random(5,10)/10
	HitSound.MaxDistance = 500
	HitSound.EmitterSize = 10
	HitSound.PlaybackSpeed = math.random(34, 50)/40
	HitSound.SoundId = "rbxassetid://" .. SoundType[math.random(1, #SoundType)]
	HitSound:Play()
	if HitSound.TimeLength > MaxTime then MaxTime = HitSound.TimeLength end
	Debris:AddItem(Attachment,MaxTime) -- Destroy attachment after all effects and sounds are done
end


function Hitmarker.HitEffect(Position, HitPart, Normal, Material, Class)
	--print(HitPart)
	local Attachment = Instance.new("Attachment")
	Attachment.CFrame = CFrame.new(Position, Position + Normal)
	Attachment.Parent = workspace.Terrain
	
	if HitPart then
		if not Material then
			Material = HitPart.Material
		end
		
		if (HitPart.Name == "Head" or HitPart.Parent.Name == "Top") then
			CreateEffect("Headshot",Attachment, nil, nil, Class)
		elseif HitPart:IsA("BasePart") and (HitPart.Parent:FindFirstChild("Humanoid") or HitPart.Parent.Parent:FindFirstChild("Humanoid") or (HitPart.Parent.Parent.Parent and HitPart.Parent.Parent.Parent:FindFirstChild("Humanoid"))) then
			CreateEffect("Hit",Attachment, nil, nil, Class)
		elseif HitPart.Parent:IsA("Accessory") then -- Didn't feel like putting this in the other one
			CreateEffect("Hit",Attachment, nil, nil, Class)

		elseif Material == Enum.Material.Wood 
			or Material == Enum.Material.WoodPlanks
			or Material == Enum.Material.RoofShingles
		then
			CreateEffect("Wood",Attachment, nil, nil, Class)

		elseif Material == Enum.Material.Concrete -- Stone stuff
			or Material == Enum.Material.Granite
			or Material == Enum.Material.Slate
			or Material == Enum.Material.Brick
			or Material == Enum.Material.Pebble
			or Material == Enum.Material.Cobblestone
			or Material == Enum.Material.Marble
			or Material == Enum.Material.CeramicTiles
			or Material == Enum.Material.ClayRoofTiles

			-- Terrain materials
			or Material == Enum.Material.Basalt
			or Material == Enum.Material.Asphalt
			or Material == Enum.Material.Pavement
			or Material == Enum.Material.Rock
			or Material == Enum.Material.CrackedLava
			or Material == Enum.Material.Sandstone
			or Material == Enum.Material.Limestone
		then
			CreateEffect("Stone",Attachment, nil, nil, Class)

		elseif Material == Enum.Material.Metal -- Metals
			or Material == Enum.Material.CorrodedMetal
			or Material == Enum.Material.DiamondPlate
			or Material == Enum.Material.Neon
			-- Terrain materials
			or Material == Enum.Material.Salt
		then
			CreateEffect("Metal",Attachment, nil, nil, Class)

		elseif Material == Enum.Material.Grass -- Ground stuff
			-- Terrain materials
			or Material == Enum.Material.Ground
			or Material == Enum.Material.LeafyGrass
			or Material == Enum.Material.Mud
		then
			CreateEffect("Ground",Attachment, nil, nil, Class)

		elseif Material == Enum.Material.Sand -- Soft things
			or Material == Enum.Material.Carpet
			or Material == Enum.Material.Fabric
			or Material == Enum.Material.Leather
			or Material == Enum.Material.Rubber
			-- Terrain materials
			or Material == Enum.Material.Snow
		then
			CreateEffect("Sand",Attachment,true,HitPart, Class)

		elseif Material == Enum.Material.Foil -- Brittle things
			or Material == Enum.Material.Ice
			or Material == Enum.Material.Glass
			or Material == Enum.Material.ForceField

		then
			CreateEffect("Glass",Attachment,true,HitPart, Class)
		else
			CreateEffect("Stone",Attachment, nil, nil, Class)
		end
	--elseif Position then
	--	CreateEffect("Stone",Attachment, nil, nil, Class)
	else
		Attachment:Destroy()
	end
end

return Hitmarker