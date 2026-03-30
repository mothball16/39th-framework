--// Custom Prompt
--// Made by zddeisRBLX
--// Modified by Jarr for Dragoon's Den
--// Extended with Tweened Appear/Disappear by ChatGPT and @tony1456578

local Buttons = require(script:WaitForChild("Buttons"))

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local SitConnection

local PLAY_SOUND = true --play a sound when a prompt appears?
local APPEAR_TIME = 0.2
local DISAPPEAR_TIME = 0.2

local function getScreenGui()
	local screenGui = PlayerGui:FindFirstChild("ProximityPrompts")
	if screenGui == nil then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "ProximityPrompts"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = PlayerGui
	end
	return screenGui
end

local function DisconnectFunction(Func)
	if Func then Func:Disconnect() end
end

local function Update_yScale(StartingTime,EndingTime,prompt,promptUI,RenderStepped)
	if not promptUI or not promptUI:FindFirstChildOfClass("Frame") then 
		DisconnectFunction(RenderStepped)
		return 
	end
	
	local Time = tick()
	local yScale = (math.clamp(Time,StartingTime,EndingTime) - StartingTime) / prompt.HoldDuration

	promptUI.Frame.ButtonFrame.ProgressBar.Size = UDim2.new(1,0,yScale,0)

	if yScale >= 1 then
		promptUI.Frame.ButtonFrame.ProgressBar.Size = UDim2.new(1,0,0,0)
		DisconnectFunction(RenderStepped)
	end
end

local function GetStringFromKey(KeyboardKeyCode)
	for String, KeyCode in pairs(Buttons) do
		if KeyCode == KeyboardKeyCode then else continue end
		return String
	end
end

local function AnimatePromptIn(promptUI)
	local originalSize = promptUI.Frame.Size
	promptUI.Frame.Size = UDim2.new(0, 0, 0, 0)
	promptUI.Frame.BackgroundTransparency = 1

	local sizeTween = TweenService:Create(promptUI.Frame, TweenInfo.new(APPEAR_TIME, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Size = originalSize,
		--BackgroundTransparency = 0.25
	})
	sizeTween:Play()
end

local function AnimatePromptOut(promptUI)
	local tweenOut = TweenService:Create(promptUI.Frame, TweenInfo.new(DISAPPEAR_TIME, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
		--BackgroundTransparency = 1
	})
	tweenOut:Play()
	tweenOut.Completed:Wait()
end

local function CreatePrompt(prompt, inputType, gui)
	local promptUI = script:WaitForChild("Prompt"):Clone()
	promptUI.Enabled = true
	promptUI.Adornee = prompt.Parent
	promptUI.Parent = gui
	promptUI.Frame.ButtonFrame.ButtonText.Text = GetStringFromKey(prompt.KeyboardKeyCode)
	promptUI.Frame.TextFrame:WaitForChild("ActionText").Text = prompt.ActionText
	promptUI.Frame.TextFrame:WaitForChild("ObjectText").Text = prompt.ObjectText

	-- Tween appear
	AnimatePromptIn(promptUI)
	if PLAY_SOUND then
		script.PromptAppear:Play()
	end

	local highlightEnabled = prompt:GetAttribute("Highlight_Enabled")
	local highlight
	if highlightEnabled==true then
		local backgrColor = prompt:GetAttribute("Highlight_BackgroundColor")
		local borderColor = prompt:GetAttribute("Highlight_BorderColor")
		local backgrTrans = prompt:GetAttribute("Highlight_BackgroundTransparency")
		local borderTrans = prompt:GetAttribute("Highlight_BorderTransparency")
		local hlTarget = prompt:FindFirstChild("Highlight")

		highlight = Instance.new("Highlight")
		highlight.Name = prompt.Name
		highlight.FillColor = backgrColor
		highlight.FillTransparency = backgrTrans
		highlight.OutlineColor = borderColor
		highlight.OutlineTransparency = borderTrans

		if hlTarget then 
			highlight.Adornee = hlTarget.Value 
		else 
			highlight.Adornee = prompt.Parent
		end
		highlight.Parent = prompt
		highlight.Enabled = true
	end

	local Holding = false
	local Began = nil
	local Triggered = nil

	Triggered = prompt.Triggered:Connect(function()
		if prompt.HoldDuration == 0 then else return end

		--promptUI.Frame.ButtonFrame.BackgroundColor3 = Color3.new(0.5,0.5,0.5)
		TweenService:Create(promptUI.Frame.ButtonFrame,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{BackgroundColor3 = Color3.new(0,0,0)}):Play()
	end)

	Began = prompt.PromptButtonHoldBegan:Connect(function()
		local StartingTime = tick()
		local EndingTime = StartingTime + prompt.HoldDuration

		local RenderStepped = nil
		RenderStepped = RunService.RenderStepped:Connect(function()
			if not prompt then DisconnectFunction(RenderStepped) return end
			Update_yScale(StartingTime,EndingTime,prompt,promptUI,RenderStepped)
		end)

		local Ended = nil
		Ended = prompt.PromptButtonHoldEnded:Connect(function()
			DisconnectFunction(RenderStepped)
			DisconnectFunction(Ended)

			TweenService:Create(promptUI.Frame.ButtonFrame.ProgressBar,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{BackgroundTransparency = 1}):Play()

			task.wait(0.25)

			if not promptUI or not promptUI:FindFirstChild("Frame") or not promptUI.Frame:FindFirstChild("ButtonFrame") then  return end

			promptUI.Frame.ButtonFrame.ProgressBar.BackgroundTransparency = 0.5
			promptUI.Frame.ButtonFrame.ProgressBar.Size = UDim2.new(1,0,0,0)
		end)
	end)

	local Down = nil
	Down = promptUI.Frame.TextButton.MouseButton1Down:Connect(function()
		prompt:InputHoldBegin()

		local StartingTime = tick()
		local EndingTime = StartingTime + prompt.HoldDuration

		local RenderStepped = nil
		RenderStepped = RunService.RenderStepped:Connect(function()
			Update_yScale(StartingTime,EndingTime,prompt,promptUI,RenderStepped)
		end)

		local Up = nil
		Up = promptUI.Frame.TextButton.MouseButton1Up:Connect(function()
			prompt:InputHoldEnd()
			promptUI.Frame.ButtonFrame.ProgressBar.Size = UDim2.new(1,0,0,0)

			DisconnectFunction(RenderStepped)
			DisconnectFunction(Up)
		end)
	end)

	prompt.PromptHidden:Wait()
	AnimatePromptOut(promptUI)
	promptUI:Destroy()
	if highlight then highlight:Destroy() end

	DisconnectFunction(Triggered)
	DisconnectFunction(Began)
	DisconnectFunction(Down)
end

local function onSit(sitting)
	ProximityPromptService.Enabled = not sitting
end

local function onLoad()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Default then return end
		if not SitConnection and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid") then SitConnection=nil; SitConnection=LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid").Seated:Connect(onSit) end	

		local gui = getScreenGui()
		CreatePrompt(prompt, inputType, gui)
	end)

	task.wait(5)
	if not SitConnection and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid") then SitConnection=nil; SitConnection=LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid").Seated:Connect(onSit) end	
end

LocalPlayer.CharacterAdded:Connect(function()
	local human:Humanoid = LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid")
	if not human then warn("CustomPrompt - No Humanoid Found for "..LocalPlayer.Name.."'s character!"); return end

	SitConnection=human.Seated:Connect(onSit)
	print(human.Sit)
	onSit(false)

	task.wait(10)
	if not SitConnection and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid") then SitConnection=nil; SitConnection=LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid").Seated:Connect(onSit) end	
end)

LocalPlayer.CharacterAppearanceLoaded:Connect(function()
	if not SitConnection and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid") then SitConnection=nil; SitConnection=LocalPlayer.Character:FindFirstChildWhichIsA("Humanoid").Seated:Connect(onSit) end	
end)

onLoad()