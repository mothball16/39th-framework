--[[       
	INFRARED VISION SYSTEM
	DTS/SPH/UCS/INT
	1.1.2

	Made by Jarr (@SrJarr)
--]]

--// Services
local DS = game:GetService("Debris")
local tween = game:GetService("TweenService")
local collection = game:GetService("CollectionService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local flirmod = {}

--// Folders
local sphCore = replicatedStorage:FindFirstChild("SPH_Framework")
local sphInstall = replicatedStorage:FindFirstChild("SPH_Assets")
local dtsInstall = replicatedStorage:FindFirstChild("DTS_Assets")
local ucsInstall = replicatedStorage:FindFirstChild("UCS_Assets") --BRIDGENET ORDER: SPH -> DTS -> UCS. You need one of these!! Bad things might happen if you have SMS/USS without SPH or DTS...
local bridgeNet = (sphCore and require(sphCore.Network.BridgeNet))
	or (sphInstall and sphInstall:FindFirstChild("Modules") and require(sphInstall.Modules.Network.BridgeNet))
	or (dtsInstall and require(dtsInstall.Modules.BridgeNet))
	or (ucsInstall and require(ucsInstall.Modules.BridgeNet))
if not bridgeNet then error("NightVision: No SPH/DTS/UCS systems installed, you need at least 1!!") return end

local nvgAnim = bridgeNet.CreateBridge("NightVision_Anim")

local tgtMod = require(replicatedStorage.INTERACT_Assets.Modules.TargetingSystem)

local sampleEffect = script.InfraredEffect
local sampleEffect2 = script.NightVisionEffect
local sampleEffect3 = script.NightVisionBloom
local sampleUI = script.FLIR_UI

local markedTargets = {}
local rng = Random.new()
local cache = os.clock()
local defaultExposure = 0

local config = 
	{
		IR_MaxDistance = 750,

		IR_Tags = {"Okami_Chassis", "Dragoon_Vehicle", "Dragoon_Compat", "NightVis_InfraredObject", "NPC_Civilian", "NPC_Dummy"},
		IR_Countermeasures = {"Countermeasures_Smoke"}, --Models with these tags WONT SHOW
		IR_ShowSelf = true, --Should the player/player's vehicle be highlighted?
		IR_ShowMorphs = false, --Should we highlight the morphs inside a player at a different temp?
		IR_MorphTemp = -0.25, --Multipliers the color/temperature of the morphs in a player. 0.5 is the middle between 0=cold and 1=hot

		NVG_TweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad),
		NVG_InfraredColors = {Color3.fromRGB(0, 0, 0), Color3.fromRGB(255, 255, 255)}, --Cold to hot, the default value will be in the middle
		NVG_TintColors = {Color3.fromRGB(0, 80, 0), Color3.fromRGB(0,215,0)} --Cold to hot, the default value will be in the middle
	}

--// Functions
local function Recursive(parent,root)
	for k,v in parent:GetChildren() do
		if v:IsA("BasePart") then
			local w = Instance.new("Weld")
			w.Part0 = root
			w.Part1 = v
			w.C1 = v.CFrame:toObjectSpace(root.CFrame)
			w.Parent = root
			v.Anchored = false
			v.CanCollide = false
		elseif v:IsA("Model") and v.Name ~= "Up" then
			Recursive(v,root)
		end
	end
end

local function NvgAnim(player:Player, nvg:Model, up:Model, rotator:Motor6D, upCF:CFrame, downCF:CFrame, override:boolean?)
	if not nvg then return end
	if player.Character and not nvg:IsDescendantOf(player.Character) then return end

	local enabled = nvg:GetAttribute("NightVis_Enabled")
	if override~=nil and enabled==override then return end
	nvg:SetAttribute("NightVis_Enabled", not enabled)

	--Run code
	enabled = nvg:GetAttribute("NightVis_Enabled")
	if rotator then 
		if rotator.Name ~= "twistjoint" or not rotator:IsDescendantOf(nvg) or not rotator:IsDescendantOf(player.Character) then return end

		local tweenUp = tween:Create(rotator, config.NVG_TweenInfo, {C0 = upCF})
		local tweenDown = tween:Create(rotator, config.NVG_TweenInfo, {C0 = downCF})

		if enabled then
			tweenDown:Play()
		else
			tweenUp:Play()
		end
	end

	up.Middle.armsound:Play()

	if nvg:GetAttribute("LBrick_ChangeMaterials") then
		for _, lens in up:GetChildren() do
			if lens.Name~="Lens" then continue end
			lens.Color = (enabled and nvg:GetAttribute("LBrick_ColorOn") or nvg:GetAttribute("LBrick_ColorOff"))
			lens.Material = (enabled and Enum.Material.Neon) or Enum.Material.Glass
		end		
	end
end

local function GetTemperature(tgtTemp:number?, tint:boolean):Color3
	local colorPalette:{Color3} = (tint and config.NVG_TintColors) or config.NVG_InfraredColors

	if tgtTemp and tgtTemp>0 then
		tgtTemp = math.map(tgtTemp, 0, 1, 0.5, 1) --math.clamp(math.abs(tgtTemp), 0, 1)
		return colorPalette[1]:Lerp(colorPalette[2], tgtTemp)
	elseif tgtTemp and tgtTemp<0 then
		tgtTemp = math.map(tgtTemp, -1, 0, 0.5, 1) --math.clamp(1-math.abs(tgtTemp), 0, 1)
		return colorPalette[2]:Lerp(colorPalette[1], 1.5-tgtTemp)
	else
		return colorPalette[1]:Lerp(colorPalette[2], 0.5)
	end
end

function flirmod.Initialize()
	if config.IR_InvertColors then
		sampleEffect.Brightness = 0.125
		sampleEffect.TintColor = Color3.fromRGB(255, 255, 255)
	end

	nvgAnim:Connect(NvgAnim)
	defaultExposure = game.Lighting.ExposureCompensation
end

function flirmod.GiveNVG(player:Player, model:Model, fakePlayer)
	local upnvg = model:FindFirstChild("Up")
	local downnvg = model:FindFirstChild("Down")
	if upnvg and downnvg then
		Recursive(upnvg, upnvg.PrimaryPart)

		local upvalue = Instance.new("CFrameValue")
		upvalue.Name = "upvalue"
		upvalue.Value = model.Middle.CFrame:inverse()*upnvg.PrimaryPart.CFrame
		upvalue.Parent = upnvg

		local downvalue = Instance.new("CFrameValue")
		downvalue.Name = "downvalue"
		downvalue.Value = model.Middle.CFrame:inverse()*downnvg.PrimaryPart.CFrame
		downvalue.Parent = upnvg

		local nvgjoint = Instance.new("Motor6D")
		nvgjoint.Part0 = model.Middle
		nvgjoint.Part1 = upnvg.PrimaryPart
		nvgjoint.Name = "twistjoint"
		nvgjoint.C0 = upvalue.Value
		nvgjoint.Parent = upnvg

		downnvg:Destroy()
	elseif upnvg or downnvg then
		--print("Missing "..(not upnvg and "Up" or "Down").."NVG Model")
		--^^^not a problem anymore
	end

	local function CNVG(char)
		local oldModel:Model? = char:FindFirstChild(model.Name)
		if oldModel then oldModel:Destroy() end

		local newModel = model:Clone()
		Recursive(newModel, newModel.Middle)

		local morphWeld = Instance.new("Weld")
		morphWeld.Part0 = char.Head
		morphWeld.Part1 = newModel.Middle
		morphWeld.Parent = morphWeld.Part0

		newModel.Parent = char
		return newModel
	end

	if player then
		local newModel = CNVG(player.Character)
		local newUI = newModel:FindFirstChildWhichIsA("ScreenGui")

		if newUI then
			local uiRef = Instance.new("ObjectValue")
			uiRef.Name = "UI_morph"
			uiRef.Value = newUI
			uiRef.Parent = player.character

			newUI.Morph.Value = newModel
			newUI.Parent = player.PlayerGui
			newUI.NightVision.Enabled = true
		end
	else
		CNVG(fakePlayer)
	end
end

function flirmod.LoadNV(player:Player, playerCam:Camera, screenGui:ScreenGui) --Activates IR if its not activated already
	--Add camera effects
	local irEffect = playerCam:FindFirstChild("InfraredEffect")
	if irEffect then irEffect:Destroy() end

	local nvEffect = playerCam:FindFirstChild("NightVisionEffect")
	if not nvEffect then 
		nvEffect = sampleEffect2:Clone()  
		nvEffect.Parent = playerCam
	end

	local nvBloom = playerCam:FindFirstChild("NightVisionBloom")
	if not nvBloom then
		nvBloom = sampleEffect3:Clone()
		nvBloom.Parent = playerCam
	end

	--Add UI
	local irUI = screenGui:FindFirstChild("FLIR_UI")
	if not irUI then 
		local newUI = sampleUI:Clone()  
		newUI.Parent = screenGui
	end

	screenGui.View0.FLIR_On:Play()
end

function flirmod.RemoveNV(player:Player, playerCam:Camera, screenGui:ScreenGui)
	--Remove camera effects
	local irEffect = playerCam:FindFirstChild("InfraredEffect")
	if irEffect then irEffect:Destroy() end

	local nvEffect1 = playerCam:FindFirstChild("NightVisionEffect")
	if nvEffect1 then nvEffect1:Destroy() end

	local nvEffect2 = playerCam:FindFirstChild("NightVisionBloom")
	if nvEffect2 then nvEffect2:Destroy() end

	--Remove UI
	local irUI = screenGui:FindFirstChild("FLIR_UI")
	if irUI then irUI:Destroy() end

	screenGui.View0.FLIR_Off:Play()
end


function flirmod.LoadIR(player:Player, playerCam:Camera, screenGui:ScreenGui) --Activates IR if its not activated already
	--Create a highlight folder if there's none
	local hlFolder = player:FindFirstChild("IR_Highlights")
	if not hlFolder then
		hlFolder = Instance.new("Folder")
		hlFolder.Name = "IR_Highlights"
		hlFolder.Parent = player
	end

	--Add camera effects
	local irEffect = playerCam:FindFirstChild("InfraredEffect")
	if not irEffect then 
		local newEffect = sampleEffect:Clone()  
		newEffect.Parent = playerCam
	end

	local nvBloom = playerCam:FindFirstChild("NightVisionBloom")
	if not nvBloom then
		nvBloom = sampleEffect3:Clone()
		nvBloom.Parent = playerCam
	end

	--Add UI
	local irUI = screenGui:FindFirstChild("FLIR_UI")
	if not irUI then 
		local newUI = sampleUI:Clone()  
		newUI.Parent = screenGui
	end

	screenGui.View0.FLIR_On:Play()
end

function flirmod.RemoveIR(player:Player, playerCam:Camera, screenGui:ScreenGui)
	--Remove camera effects
	local irEffect = playerCam:FindFirstChild("InfraredEffect")
	if irEffect then irEffect:Destroy() end

	local nvEffect1 = playerCam:FindFirstChild("NightVisionEffect")
	if nvEffect1 then nvEffect1:Destroy() end

	local nvEffect2 = playerCam:FindFirstChild("NightVisionBloom")
	if nvEffect2 then nvEffect2:Destroy() end

	--Remove UI
	local irUI = screenGui:FindFirstChild("FLIR_UI")
	if irUI then irUI:Destroy() end

	screenGui.View0.FLIR_Off:Play()

	--Clean up highlights
	local hlFolder = player:FindFirstChild("IR_Highlights")
	if not hlFolder then return end
	for _, hl in hlFolder:GetChildren() do
		hl:Destroy()
	end
	table.clear(markedTargets)
end

function flirmod.ResetExposure()
	game.Lighting.ExposureCompensation = defaultExposure
end

function flirmod.RenderExposure(newExposure)
	if newExposure and game.Lighting.ExposureCompensation~=newExposure then
		game.Lighting.ExposureCompensation = newExposure
	end
end

function flirmod.RenderNoise(player:Player, playerCam:Camera, screenGui:ScreenGui) --Use only if not using render highlights!
	local irUI = screenGui:FindFirstChild("FLIR_UI")
	if not irUI then return end

	--render noise effet
	if os.clock() - cache > 1 / 30 then
		cache = os.clock()
		irUI.NoiseEffect.Position = UDim2.fromScale(rng:NextNumber(-1, 0), rng:NextNumber(-1, 0))
	end
end

function flirmod.RenderHighlights(player:Player, playerCam:Camera, screenGui:ScreenGui, tint:boolean, vehicle:model, dt)
	local hlFolder = player:FindFirstChild("IR_Highlights")
	if not hlFolder then return end

	local irUI = screenGui:FindFirstChild("FLIR_UI")
	if not irUI then return end

	local sampleHighlight = script.TargetHighlight


	--Add our current model, if theres any
	if config.IR_ShowSelf and vehicle then
		if markedTargets[vehicle]==nil then
			markedTargets[vehicle] = true

			local tgtHighlight = sampleHighlight:Clone()
			local tgtTemp = vehicle:GetAttribute("NightVis_Temperature")
			tgtHighlight.Name = vehicle.Name
			tgtHighlight.Parent = hlFolder
			tgtHighlight.Adornee = vehicle
			tgtHighlight.FillColor = GetTemperature(tgtTemp, tint)
		end
	end
	if config.IR_ShowSelf and player and player.Character then
		if markedTargets[player.Character]==nil then
			markedTargets[player.Character] = true

			local tgtHighlight = sampleHighlight:Clone()
			local tgtTemp = player.Character:GetAttribute("NightVis_Temperature")
			tgtHighlight.Name = player.Name
			tgtHighlight.Parent = hlFolder
			tgtHighlight.Adornee = player.Character
			tgtHighlight.FillColor = GetTemperature(tgtTemp, tint)

			if config.IR_ShowMorphs then
				for _, morph in player.Character:GetChildren() do
					if not morph:IsA("Model") then continue end
					if not config.IR_ShowSelf and player.Character == player.Character then continue end
					if not string.find(morph.Name, "_morph") then continue end

					markedTargets[morph] = true

					local tgtHighlight = sampleHighlight:Clone()
					local tgtTemp = morph:GetAttribute("NightVis_Temperature") or config.IR_MorphTemp
					tgtHighlight.Name = player.Name.."/"..morph.Name
					tgtHighlight.Parent = hlFolder
					tgtHighlight.Adornee = morph
					tgtHighlight.FillColor = GetTemperature(tgtTemp, tint)
				end
			end
		end
	end

	--Add new models
	for _, tag in config.IR_Tags do
		for each, object:Model in collection:GetTagged(tag) do
			if not object:IsA("Model") or not object:IsDescendantOf(game.Workspace) then continue end
			if not tgtMod.IsTargetInFov(playerCam.FieldOfView, playerCam.CFrame, object:GetPivot().Position, 10) then continue end

			if markedTargets[object]~=nil then continue end

			local dist = (playerCam.CFrame.Position - object.WorldPivot.Position).Magnitude
			if dist>config.IR_MaxDistance*0.9 then continue end

			local countermeasures = tgtMod.TablesShareElement(object:GetTags(), config.IR_Countermeasures)
			if countermeasures then continue end

			--Highlight Target
			markedTargets[object] = true

			local tgtHighlight = sampleHighlight:Clone()
			local tgtTemp = object:GetAttribute("NightVis_Temperature")
			tgtHighlight.Name = object.Name
			tgtHighlight.Parent = hlFolder
			tgtHighlight.Adornee = object
			tgtHighlight.FillColor = GetTemperature(tgtTemp, tint)
		end
	end
	for each, otherPlayer in game.Players:GetPlayers() do
		if otherPlayer==player or not otherPlayer.Character or not otherPlayer.Character:FindFirstChild("HumanoidRootPart") then continue end
		if not tgtMod.IsTargetInFov(playerCam.FieldOfView, playerCam.CFrame, otherPlayer.Character.HumanoidRootPart.Position, 10) then continue end

		if markedTargets[otherPlayer.Character]~=nil then continue end

		local dist = (playerCam.CFrame.Position - otherPlayer.Character.HumanoidRootPart.Position).Magnitude
		if dist>config.IR_MaxDistance*0.9 then continue end

		--Highlight Target
		markedTargets[otherPlayer.Character] = true

		local tgtHighlight = sampleHighlight:Clone()
		local tgtTemp = otherPlayer.Character:GetAttribute("NightVis_Temperature")
		tgtHighlight.Name = otherPlayer.Name
		tgtHighlight.Parent = hlFolder
		tgtHighlight.Adornee = otherPlayer.Character
		tgtHighlight.FillColor = GetTemperature(tgtTemp, tint)

		if config.IR_ShowMorphs then
			for _, morph in otherPlayer.Character:GetChildren() do
				if not morph:IsA("Model") then continue end
				if not config.IR_ShowSelf and otherPlayer.Character == player.Character then continue end
				if not string.find(morph.Name, "_morph") then continue end

				markedTargets[morph] = true

				local tgtHighlight = sampleHighlight:Clone()
				local tgtTemp = morph:GetAttribute("NightVis_Temperature") or config.IR_MorphTemp
				tgtHighlight.Name = otherPlayer.Name.."/"..morph.Name
				tgtHighlight.Parent = hlFolder
				tgtHighlight.Adornee = morph
				tgtHighlight.FillColor = GetTemperature(tgtTemp, tint)
			end
		end
	end

	--Remove models that are not in range
	for object:Model, value in markedTargets do
		local dist = (playerCam.CFrame.Position - object.WorldPivot.Position).Magnitude
		local plr = game.Players:GetPlayerFromCharacter(object)

		if (vehicle and object==vehicle) or (plr and plr==player) then continue end

		local inView = tgtMod.IsTargetInFov(playerCam.FieldOfView, playerCam.CFrame, object:GetPivot().Position, 15)
		if dist<config.IR_MaxDistance and inView then  continue end

		local countermeasures = tgtMod.TablesShareElement(object:GetTags(), config.IR_Countermeasures)
		if not countermeasures then continue end

		local highlight = hlFolder:FindFirstChild(object.Name)
		if highlight then highlight:Destroy() end
		markedTargets[object] = nil

	end

	--render noise effet
	local irNoise = irUI:FindFirstChild("NoiseEffect")
	if os.clock() - cache > 1 / 30 and irNoise then
		cache = os.clock()
		irNoise.Position = UDim2.fromScale(rng:NextNumber(-1, 0), rng:NextNumber(-1, 0))
	end
end

return flirmod