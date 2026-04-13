-- Visual-only attachment placement (clone + weld). No stat aggregation.

local M = {}

function M.place(assets, weldMod, weapon, attachmentSlot, weaponAttachment, parentPart)
	local attac = assets.Attachments:FindFirstChild(weaponAttachment)
	if not attac then
		warn("Model for " .. weaponAttachment .. " not found")
		return nil
	end
	local template = attac:FindFirstChild("AttachmentModel")
	if not template then
		return nil
	end
	local newAttachment = template:Clone()
	newAttachment.Parent = weapon
	newAttachment.Name = weaponAttachment

	local slotPart = parentPart:FindFirstChild(attachmentSlot)
	if newAttachment.PrimaryPart and slotPart then
		newAttachment:SetPrimaryPartCFrame(slotPart.CFrame)
		weldMod.WeldModel(newAttachment, slotPart, false)
	else
		warn("Attachment " .. weaponAttachment .. " has no PrimaryPart and cannot be positioned properly!")
	end

	local main = newAttachment:FindFirstChild("Main")
	if main and main:FindFirstChild("Muzzle") and weapon:FindFirstChild("Grip") then
		local grip = weapon.Grip
		local gripMuzzle = grip:FindFirstChild("Muzzle")
		if gripMuzzle then
			gripMuzzle.WorldCFrame = main.Muzzle.WorldCFrame
		end
	end

	return newAttachment
end

return M
