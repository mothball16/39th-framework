local SoundService = game:GetService("SoundService")


return function(): {
    fireMain: SoundGroup,
    fireEcho: SoundGroup,
}
	return {
		fireMain = SoundService:WaitForChild("FireMain"),
		fireEcho = SoundService:WaitForChild("FireEcho"),
	}
end