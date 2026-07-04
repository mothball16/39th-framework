local SoundService = game:GetService("SoundService")

local function getOrCreateSoundGroup(name: string): SoundGroup
	local group = SoundService:FindFirstChild(name)
	if not group then
		group = Instance.new("SoundGroup")
		group.Name = name
		group.Parent = SoundService
	end
	return group :: SoundGroup
end

local function applyFireEchoEffects(group: SoundGroup)
	local equalizer = group:FindFirstChildOfClass("EqualizerSoundEffect")
	if not equalizer then
		equalizer = Instance.new("EqualizerSoundEffect")
		equalizer.Name = "EqualizerSoundEffect"
		equalizer.Parent = group
	end
	equalizer.Enabled = true
	equalizer.LowGain = 5
	equalizer.MidGain = -10
	equalizer.HighGain = -60
	equalizer.Priority = 0

	local compressor = group:FindFirstChildOfClass("CompressorSoundEffect")
	if not compressor then
		compressor = Instance.new("CompressorSoundEffect")
		compressor.Name = "CompressorSoundEffect"
		compressor.Parent = group
	end
	compressor.Enabled = true
	compressor.Attack = 0.01
	compressor.Release = 0.5
	compressor.Threshold = -20
	compressor.Ratio = 10
	compressor.GainMakeup = 5
	compressor.Priority = 0
end

return function()
	getOrCreateSoundGroup("FireMain")
	applyFireEchoEffects(getOrCreateSoundGroup("FireEcho"))
end
