--[[       
DRAGOON TANK SYSTEM
FX Module
1.2.0
--]]

--// Services
local DS = game:GetService("Debris")
local replicatedStorage = game:GetService("ReplicatedStorage")
local FXMod = {}

--// Folders
local assets = replicatedStorage.DTS_Assets
local fx = assets.FX

--// Functions
function FXMod.PlayLocalFX(effect)
	if effect:IsA("ParticleEmitter") then
		coroutine.wrap(function()	
			local fxDelay = effect:GetAttribute("fx_Delay")
			local fxDuration = effect:GetAttribute("fx_Duration")
	
			if fxDelay then 
				task.wait(fxDelay) 
			end
			effect.Enabled=true
			if fxDuration and fxDuration ~= 0 then
				task.wait(fxDuration)
				effect.Enabled=false
				DS:AddItem(effect, effect.Lifetime.Max+0.5)
			end
		end)()
	elseif effect:IsA("Sound") then
		coroutine.wrap(function()	
			local fxDelay = effect:GetAttribute("fx_Delay")
			local fxDuration = effect:GetAttribute("fx_Duration")

			if fxDelay then 
				task.wait(fxDelay) 
			end

			effect:Play()
			if effect.Looped==false then
				DS:AddItem(effect, effect.TimeLength*1.25)
			elseif fxDuration and fxDuration ~= 0 then
				DS:AddItem(effect, fxDuration)
			else
				DS:AddItem(effect, effect.TimeLength*1.25)
			end
		end)()
	elseif effect:IsA("SpotLight") or effect:IsA("SurfaceLight") or effect:IsA("PointLight") then
		coroutine.wrap(function()	
			local fxDelay = effect:GetAttribute("fx_Delay")
			local fxDuration = effect:GetAttribute("fx_Duration")
	
			if fxDelay then 
				task.wait(fxDelay) 
			end
			effect.Enabled=true
			if fxDuration and fxDuration ~= 0 then
				DS:AddItem(effect, fxDuration)
			end
		end)()
	end
end

function FXMod.PlayAllLocalFX(target)
	for _, effect in target:GetChildren() do
		FXMod.PlayLocalFX(effect)
	end
end

function FXMod.PlayAllFX(Target, Folder)
	local Effects = Folder:GetChildren()
	for _, effect in ipairs(Effects) do
		FXMod.PlayIndividualFX(Target, effect)
	end
end

function FXMod.PlayIndividualFX(Target, effect)
	if effect:IsA("ParticleEmitter") or effect:IsA("Sound") or effect:IsA("SpotLight") or effect:IsA("SurfaceLight") or effect:IsA("PointLight") then
		local fxNew = effect:Clone()
		fxNew.Parent = Target
		FXMod.PlayLocalFX(fxNew)
	end
end

function FXMod.PlayFX(player:Player, mainPart, effect)	
	local effectFind = fx:FindFirstChild(effect)
	if not effectFind then return end

	--Exit points: Points in a vehicle where fire or smoke comes out
	local exitPoints = effectFind:FindFirstChild("ExitPoints")
	if exitPoints then
		exitPoints = exitPoints:GetChildren()
		local attachments = mainPart:GetChildren()

		for _, ep in pairs(attachments) do
			if ep.Name == "FX_ExitPoint" then
				FXMod.PlayAllFX(ep, effectFind.ExitPoints["ExitPoint"..math.random(1, #exitPoints)])
			elseif ep.Name == "FX_ExitPointRef" then
				FXMod.PlayAllFX(ep.Value, effectFind.ExitPoints["ExitPoint"..math.random(1, #exitPoints)])
			end
		end
	end

	--Sounds: Play a single sound out of a selection of options or all SFX simultaneously with 'fx_PlayAll' attribute on the Sounds folder
	local sounds = effectFind:FindFirstChild("Sounds")
	if sounds then
		local PlayAllSound = sounds:GetAttribute("fx_PlayAll")
		
		sounds = sounds:GetChildren()
		if not PlayAllSound then
			local soundFind = effectFind.Sounds["S"..math.random(1, #sounds)]
			if soundFind then FXMod.PlayIndividualFX(mainPart, soundFind) end
		else
			for _, Sound in pairs(sounds) do
				if Sound and Sound:IsA("Sound") then
					FXMod.PlayIndividualFX(mainPart, Sound)
				end
			end
		end
	end

	--Run any other effects too
	FXMod.PlayAllFX(mainPart, effectFind)
end

return FXMod
