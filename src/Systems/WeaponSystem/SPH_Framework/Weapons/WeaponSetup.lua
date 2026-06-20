--!strict

local Types = require(script.Parent.Parent.Core.ConfigurationTypes)

local function applyTemplateSound(target: Sound, template: Sound)
	target.SoundId = template.SoundId
	if template.SoundGroup then
		target.SoundGroup = template.SoundGroup
	end
end

local function applySoundFolder(grip: Instance, folder: Folder)
	for _, child in folder:GetChildren() do
		if not child:IsA("Sound") then
			continue
		end
		local gripSound = grip:FindFirstChild(child.Name)
		if gripSound and gripSound:IsA("Sound") then
			applyTemplateSound(gripSound, child)
		end
	end
end

local function applyFXFolder(grip: Instance, folder: Folder)
	for _, fxTemplate in folder:GetChildren() do
		if fxTemplate:IsA("Folder") then
			local gripAttachment = grip:FindFirstChild(fxTemplate.Name)
			if gripAttachment and gripAttachment:IsA("Attachment") then
				gripAttachment:ClearAllChildren()
				for _, fx in fxTemplate:GetChildren() do
					fx:Clone().Parent = gripAttachment
				end
			else
				warn(`[SPH] useFX failed to apply for {folder.Name} as no attachment found on grip for weapon {grip.Parent and grip.Parent.Name or "unknown"}`)
			end
		end
	end
end

local function resolveFolder(soundsRoot: Folder, path: string): Folder?
	local current: Instance = soundsRoot
	for _, segment in string.split(path, "/") do
		if segment == "" then
			continue
		end
		local nextFolder = current:FindFirstChild(segment)
		if not nextFolder or not nextFolder:IsA("Folder") then
			return nil
		end
		current = nextFolder
	end
	return if current == soundsRoot then nil else current :: Folder
end

local function applyUseSound(grip: Instance, soundsRoot: Folder, useSound: { string })
	for _, path in useSound do
		local folder = resolveFolder(soundsRoot, path)
		if folder then
			applySoundFolder(grip, folder)
		else
			warn(`[SPH] useSound folder not found: {path}`)
		end
	end
end

local function applyUseFX(grip: Instance, fxRoot: Folder, useFX: { string })
	for _, path in useFX do
		local folder = resolveFolder(fxRoot, path)
		if folder then
			applyFXFolder(grip, folder)
		else
			warn(`[SPH] useFX folder not found: {path}`)
		end
	end
end

local function applySoundDists(grip: Instance, soundDists: Types.SoundDistConfig)
	for soundName, dist in soundDists do
		local sound = grip:FindFirstChild(soundName)
		if sound and sound:IsA("Sound") then
			sound.RollOffMinDistance = dist.Min
			sound.RollOffMaxDistance = dist.Max
		end
	end
end

local WeaponSetup = {}

function WeaponSetup.apply(gun: Model, wepStats: Types.WeaponStats, soundsRoot: Folder, fxRoot: Folder)
	local grip = gun:FindFirstChild("Grip")
	if not grip then
		return
	end

	if wepStats.useSound then
		applyUseSound(grip, soundsRoot, wepStats.useSound)
	end
	if wepStats.useFX then
		applyUseFX(grip, fxRoot, wepStats.useFX)
	end
	if wepStats.soundDists then
		applySoundDists(grip, wepStats.soundDists)
	end
end

return WeaponSetup
