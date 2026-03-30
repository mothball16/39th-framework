-- v 1.7.1 (unofficial)
--heavily modified by noman

--//SERVICES
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

--//SETUP
local screenGui,TIS,Remote,Bindable = script.Parent,require(script.Parent.Parent),script.Parent.Parent:WaitForChild("IndicatorRemote"), script.Parent.Parent:WaitForChild("IndicatorBindable")
screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera
local gradient = script.UIGradient

local indicatorTable = {} -- {attachment, ui, connections}

local DEFAULT_SIZE = UDim2.new(0.038, 0, 0.038, 0)

local function getWorldPosition(source)
	if not source then return nil end

	if source:IsA("Attachment") then
		return source.WorldPosition
	elseif source:IsA("BasePart") then
		return source.Position
	elseif source:IsA("Model") then
		return source:GetPivot().Position
	elseif typeof(source) == "CFrame" then
		return source.Position
	elseif typeof(source) == "Vector3" then
		return source
	end

	return nil
end


local function removeIndicator(attachment)
	if typeof(attachment) ~= "Instance" then
		return
	end

	for index = #indicatorTable, 1, -1 do
		local data = indicatorTable[index]
		local storedAttachment = data[2]

		if storedAttachment == attachment then
			local ui = data[3]
			local connections = data[4]

			if ui then
				ui:Destroy()
			end

			if connections then
				for _, connection in ipairs(connections) do
					if connection then
						connection:Disconnect()
					end
				end
			end

			table.remove(indicatorTable, index)
			break
		end
	end
end


local function createNewIndicator(attachment)
	-- if deletable, make a button, otherwise make a frame
	local newMain
	if attachment:GetAttribute("Deletable") then
		newMain = Instance.new("TextButton")
		newMain.AutoButtonColor = false
		newMain.Text = ""
		newMain.Activated:Once(function()
			if attachment and attachment:GetAttribute("Deletable") then
				removeIndicator(attachment)
			end
		end)
	else
		newMain = Instance.new("Frame")
	end

	newMain.AnchorPoint = Vector2.new(0.5, 0.5)
	newMain.Size = UDim2.new(0, 0, 0, 0)
	newMain.SizeConstraint = Enum.SizeConstraint.RelativeYY
	newMain.Name = "MainIndicator"
	newMain.BackgroundTransparency = 1

	-- visuals
	local newUICorner = Instance.new("UICorner")
	newUICorner.CornerRadius = UDim.new(0.5, 0)
	newUICorner.Parent = newMain

	local circleGradient = gradient:Clone()
	circleGradient.Parent = newMain

	-- arrow frame
	local newArrowFrame = Instance.new("Frame")
	newArrowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	newArrowFrame.Size = UDim2.fromScale(1, 1)
	newArrowFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	newArrowFrame.BackgroundTransparency = 1
	newArrowFrame.Name = "ArrowFrame"
	newArrowFrame.Parent = newMain

	local newArrowImage = Instance.new("ImageLabel")
	newArrowImage.BackgroundTransparency = 1
	newArrowImage.Image = "http://www.roblox.com/asset/?id=92170357653958"
	newArrowImage.AnchorPoint = Vector2.new(0.5, 0.5)
	newArrowImage.Position = UDim2.fromScale(0.5, 0.01)
	newArrowImage.Size = UDim2.fromScale(1, 0.58)
	newArrowImage.Name = "ArrowImage"
	newArrowImage.Parent = newArrowFrame

	local circleGradient2 = gradient:Clone()
	circleGradient2.Parent = newArrowImage

	-- icon
	local newIconImage = Instance.new("ImageLabel")
	newIconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	newIconImage.Position = UDim2.new(0.5, 0, 0.5, 0)
	newIconImage.BackgroundTransparency = 1
	newIconImage.Size = UDim2.fromScale(0.87, 0.87)
	newIconImage.Name = "IconImage"
	newIconImage.Parent = newMain

	local newNewUICorner = newUICorner:Clone()
	newNewUICorner.Parent = newIconImage

	-- text
	local newTextLabel = Instance.new("TextLabel")
	newTextLabel.Font = Enum.Font.GothamBold
	newTextLabel.Name = "TopLabel"
	newTextLabel.TextStrokeTransparency = 0.7
	newTextLabel.AnchorPoint = Vector2.new(0.5, 1)
	newTextLabel.Position = UDim2.new(0.5, 0, 0, -5)
	newTextLabel.Size = UDim2.new(1, 0, 0.5, 10)
	newTextLabel.BackgroundTransparency = 1
	newTextLabel.TextColor3 = Color3.new(1, 1, 1)
	newTextLabel.TextScaled = false
	newTextLabel.Text = ""
	newTextLabel.Parent = newMain

	-- tween pop-in
	local tweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
	TweenService:Create(newMain, tweenInfo, {Size = DEFAULT_SIZE}):Play()

	return newMain
end

local function updateIndicatorUI(attachment, indicatorUI)
	local image = attachment:GetAttribute("Image") or ""
	local enabled = attachment:GetAttribute("Enabled") or false
	local color = attachment:GetAttribute("Color")
	local text = attachment:GetAttribute("Text") or ""

	if (not enabled) or (not color) or (image == "") then
		indicatorUI.Visible = false
		return
	else
		indicatorUI.Visible = true
	end

	indicatorUI.BackgroundColor3 = color
	indicatorUI.ArrowFrame.ArrowImage.ImageColor3 = color
	indicatorUI.IconImage.Image = image

	if indicatorUI:FindFirstChild("TopLabel") then
		indicatorUI.TopLabel.TextSize = 12
		indicatorUI.TopLabel.Text = text
	end
end

local function addIndicator(source)
	local attachment

	if source:IsA("Attachment") then
		attachment = source
	else
		local parent
		if source:IsA("BasePart") then
			parent = source
		elseif source:IsA("Model") then
			parent = source.PrimaryPart or source:FindFirstChildWhichIsA("BasePart")
		end

		if not parent then return end

		attachment = Instance.new("Attachment")
		attachment.Name = "Indicator"
		attachment.Parent = parent
	end

	removeIndicator(attachment)

	local newIndicator = createNewIndicator(attachment)
	local connections = {}
	
	connections[#connections + 1] = attachment:GetAttributeChangedSignal("Expiring"):Connect(function()
		if attachment:GetAttribute("Expiring") == true then
			-- Create the disappear animation
			local shrinkInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			local shrinkTween = TweenService:Create(newIndicator, shrinkInfo, {
				Size = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1
			})

			shrinkTween:Play()

			-- Fade out the text and images simultaneously
			for _, child in ipairs(newIndicator:GetDescendants()) do
				if child:IsA("ImageLabel") then
					TweenService:Create(child, shrinkInfo, {ImageTransparency = 1}):Play()
				elseif child:IsA("TextLabel") then
					TweenService:Create(child, shrinkInfo, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
				end
			end
		end
	end)

	connections[#connections + 1] =
		attachment.AttributeChanged:Connect(function(name)
			if name == "Image" or name == "Color" or name == "Enabled" or name == "Text" then
				updateIndicatorUI(attachment, newIndicator)
			end
		end)
	
	table.insert(indicatorTable, {source, attachment, newIndicator, connections})
	updateIndicatorUI(attachment, newIndicator)
	newIndicator.Parent = screenGui
end


local function updateIndicatorPositions()
	if screenGui.Enabled == false then return end
	if not indicatorTable[1] then return end

	local viewportX, viewportY = camera.ViewportSize.X, camera.ViewportSize.Y
	local bufferSize = indicatorTable[1][3].AbsoluteSize.X
	local camCFrame = camera.CFrame
	local maxBoundsX, maxBoundsY = viewportX - (bufferSize*2), viewportY - (bufferSize*2)
	local screenHypotenuse = math.sqrt((maxBoundsX/2)^2 + (maxBoundsY/2)^2)

	for _, data in ipairs(indicatorTable) do
		local source = data[1]
		local attachment = data[2]
		local indicatorUI = data[3]
		if not indicatorUI.Visible then continue end

		local position = getWorldPosition(source or attachment)
		if not position then continue end
		local distance = (position - camCFrame.Position).Magnitude

		-- --- Transparency calculation (fade behavior) ---
		local minDistance, maxDistance = 2, 50
		local fadeRatio = 1 - math.clamp((distance - minDistance) / (maxDistance - minDistance), 0, 1)
		local transparency = fadeRatio

		indicatorUI.Transparency = transparency
		indicatorUI.ArrowFrame.ArrowImage.ImageTransparency = transparency
		indicatorUI.IconImage.ImageTransparency = transparency

		-- --- ZIndex calculation (guaranteed stacking by distance) ---
		local orderRatio = 1 / (distance + 1)
		indicatorUI.ZIndex = math.floor(orderRatio * 100000)

		-- Screen positioning
		local screenPos, onScreen = camera:WorldToViewportPoint(position)
		local minX, maxX = bufferSize, math.max(bufferSize, viewportX - bufferSize)
		local minY, maxY = bufferSize, math.max(bufferSize, viewportY - bufferSize)
		local xPos = math.clamp(screenPos.X, minX, maxX)
		local yPos = math.clamp(screenPos.Y, minY, maxY)

		if xPos == screenPos.X and yPos == screenPos.Y and onScreen then
			indicatorUI.ArrowFrame.Visible = false
		else
			indicatorUI.ArrowFrame.Visible = true
			local worldDir = position - camCFrame.Position
			local relDir = camCFrame:VectorToObjectSpace(worldDir)
			local relDir2D = Vector2.new(relDir.X, relDir.Y).Unit
			local testPoint = relDir2D * screenHypotenuse
			local angle = math.atan2(relDir2D.X, relDir2D.Y)

			local screenPoint
			if math.abs(testPoint.Y) > maxBoundsY/2 then
				screenPoint = relDir2D * math.abs(maxBoundsY/2 / relDir2D.Y)
			else
				screenPoint = relDir2D * math.abs(maxBoundsX/2 / relDir2D.X)
			end

			xPos = viewportX/2 + screenPoint.X
			yPos = viewportY/2 - screenPoint.Y
			indicatorUI.ArrowFrame.Rotation = math.deg(angle)
		end

		indicatorUI.Position = UDim2.fromOffset(xPos, yPos)

		-- Flip text label if near screen edges
		local textLabel = indicatorUI:FindFirstChild("TopLabel")
		if textLabel then
			local offset = 5
			if yPos < bufferSize + textLabel.AbsoluteSize.Y then
				textLabel.AnchorPoint = Vector2.new(0.5, 0)
				textLabel.Position = UDim2.new(0.5, 0, 1, offset)
			elseif yPos > viewportY - bufferSize - textLabel.AbsoluteSize.Y then
				textLabel.AnchorPoint = Vector2.new(0.5, 1)
				textLabel.Position = UDim2.new(0.5, 0, 0, -offset)
			else
				textLabel.AnchorPoint = Vector2.new(0.5, 1)
				textLabel.Position = UDim2.new(0.5, 0, 0, -offset)
			end
			textLabel.TextTransparency = transparency
		end
	end
end

for _, attachment in ipairs(CollectionService:GetTagged("indicator")) do
	addIndicator(attachment)
end

CollectionService:GetInstanceAddedSignal("indicator"):Connect(addIndicator)
CollectionService:GetInstanceRemovedSignal("indicator"):Connect(removeIndicator)

Remote.OnClientEvent:Connect(function(poc,options)
	TIS.new(poc,options)
end)

Bindable.Event:Connect(function(poc, options)
	if options.Owner then
		local tag = "PingOwner_" .. options.Owner
		for _, oldObj in ipairs(CollectionService:GetTagged(tag)) do
			oldObj:Destroy()
		end
	end

	local newIndicator = TIS.new(poc, options)
	
	if options.Owner and newIndicator then
		CollectionService:AddTag(newIndicator, "PingOwner_" .. options.Owner)
	end
end)

RunService.RenderStepped:Connect(updateIndicatorPositions)