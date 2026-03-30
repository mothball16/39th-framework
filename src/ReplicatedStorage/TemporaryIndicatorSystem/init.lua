local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TemporaryIndicator = {}
TemporaryIndicator.__index = TemporaryIndicator

-- Creates a new indicator at a given position or CFrame
-- Options:
-- {
--     Duration = 5, -- optional, seconds to last
--     Text = "Target",
--     Color = Color3.fromRGB(255, 0, 0),
--     Image = "rbxassetid://6031097220"
-- }

function TemporaryIndicator.new(target, options)
	options = options or {}

	local attachment

	if typeof(target) == "Vector3" or typeof(target) == "CFrame" then
		-- fallback: static block
		local block = script.Block:Clone()
		block.Parent = workspace.LocationMarkers
		block.CFrame = typeof(target) == "CFrame" and target or CFrame.new(target)
		attachment = block:FindFirstChild("Indicator")

	elseif target:IsA("Attachment") then
		attachment = target

	elseif target:IsA("BasePart") then
		attachment = Instance.new("Attachment")
		attachment.Name = "Indicator"
		attachment.Parent = target

	elseif target:IsA("Model") then
		local part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
		if not part then return end
		attachment = Instance.new("Attachment")
		attachment.Name = "Indicator"
		attachment.Parent = part
	else
		warn("Unsupported indicator target")
		return
	end

	CollectionService:AddTag(attachment, "indicator")

	attachment:SetAttribute("Enabled", true)
	attachment:SetAttribute("Color", options.Color or Color3.fromRGB(255,100,100))
	attachment:SetAttribute("Image", options.Image or "rbxassetid://8239524757")
	attachment:SetAttribute("Text", options.Text or "")
	attachment:SetAttribute("Deletable", options.Deletable or false)
	attachment:SetAttribute("Duration", options.Duration or nil)
	
	if options.Duration and options.Duration > 0 then
		local startTime = tick()
		local connection
		local expiringTriggered = false

		connection = RunService.Heartbeat:Connect(function()
			if not attachment or not attachment.Parent then
				connection:Disconnect()
				return
			end

			local elapsed = tick() - startTime
			local remaining = options.Duration - elapsed

			if remaining <= 0.5 and not expiringTriggered then
				expiringTriggered = true
				attachment:SetAttribute("Expiring", true)
			end

			if remaining <= 0 then
				connection:Disconnect()
				if attachment.Parent and attachment.Parent.Name == "Block" then
					attachment.Parent:Destroy()
				else
					attachment:Destroy()
				end
			end
		end)
	end

	return attachment
end


return TemporaryIndicator