local respawnTime = game.Players.RespawnTime
local player = game.Players.LocalPlayer
local dead = false
local label = script.Parent
local main = script.Parent.Parent
local black = script.Parent.Parent.Blackout
local tweenService = game:GetService("TweenService")

local ending = false

repeat task.wait() until player.Character

player.Character:WaitForChild("Humanoid")
player.Character.Humanoid.Died:Connect(function()
	dead = true
	local tInfo = TweenInfo.new(1,Enum.EasingStyle.Quint)
	tweenService:Create(main,tInfo,{BackgroundTransparency = 0,Position = UDim2.fromScale(0,0)}):Play()
	tweenService:Create(label,tInfo,{TextTransparency = 0}):Play()
end)

game:GetService("RunService").RenderStepped:Connect(function(dt)
	if dead then
		respawnTime -= dt
		local finalString
		if respawnTime < 1 and not ending then
			ending = true
			local tInfo = TweenInfo.new(0.5)
			tweenService:Create(label,tInfo,{TextTransparency = 1,Position = UDim2.fromScale(0.5,0.15)}):Play()
			tweenService:Create(black,tInfo,{BackgroundTransparency = 0}):Play()
		end
		if respawnTime > 0.01 then
			local timeString = tostring(respawnTime)
			if respawnTime < 10 then
				timeString = "0"..timeString
			end
			finalString = string.sub(timeString,1,2).."."
			if #timeString >= 4 then
				finalString = finalString..string.sub(timeString,4,4)
			else
				finalString = finalString.."00"
			end
			if #timeString >= 5 then
				finalString = finalString..string.sub(timeString,5,5)
			else
				finalString = finalString.."0"
			end
		else
			finalString = "00.00"
		end
		label.Text = finalString
	end
end)