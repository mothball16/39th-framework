local gunsmith = {}

local replicatedStorage = game:GetService("ReplicatedStorage")
local sph = require(replicatedStorage.SPH_Framework.GameAccess)
local assets = sph.assets
local weldMod = require(script.Parent.WeldMod)

-- table for player's attachment stats used clientside (clears when weapon is unequipped)
gunsmith.attStats = {}

local function applyAttachmentData(attStatTable, attachment) -- apply statistical changes to an attachment data set
	if not assets.Attachments:FindFirstChild(attachment) then warn(attachment.."Not found in SPH_Assets.Attachments!") return attStatTable end

	local newAttStatTable = require(assets.Attachments[attachment].AttStats)
	local newAttModel = assets.Attachments[attachment].AttachmentModel

	-- adjust fire rate
	if newAttStatTable.fireRate then -- make your rate of fire faster or slower
		if attStatTable.fireRate then
			attStatTable.fireRate *= newAttStatTable.fireRate
		else
			attStatTable.fireRate = newAttStatTable.fireRate
		end
	end

	-- adjust reload speed
	if newAttStatTable.reloadSpeedModifier then -- make your reloads faster or slower
		if attStatTable.reloadSpeedModifier then
			attStatTable.reloadSpeedModifier *= newAttStatTable.reloadSpeedModifier
		else
			attStatTable.reloadSpeedModifier = newAttStatTable.reloadSpeedModifier
		end
	end

	if newAttStatTable.gunLength then -- make your gun longer or shorter (set .gunLength to negative if you want it shorter)
		if attStatTable.gunLength then
			attStatTable.gunLength += newAttStatTable.gunLength
		else
			attStatTable.gunLength = newAttStatTable.gunLength
		end
	end

	if newAttStatTable.recoil then
		if attStatTable.recoil then
			attStatTable.recoil.vertical *= newAttStatTable.recoil.vertical
			attStatTable.recoil.horizontal *= newAttStatTable.recoil.horizontal
			attStatTable.recoil.camShake *= newAttStatTable.recoil.camShake
			attStatTable.recoil.damping *= newAttStatTable.recoil.damping
			attStatTable.recoil.speed *= newAttStatTable.recoil.speed
			attStatTable.recoil.aimReduction *= newAttStatTable.recoil.aimReduction
		else
			attStatTable.recoil = newAttStatTable.recoil
		end
	end

	if newAttStatTable.gunRecoil then
		if attStatTable.gunRecoil then
			attStatTable.gunRecoil.vertical *= newAttStatTable.gunRecoil.vertical
			attStatTable.gunRecoil.horizontal *= newAttStatTable.gunRecoil.horizontal
			attStatTable.gunRecoil.damping *= newAttStatTable.gunRecoil.damping
			attStatTable.gunRecoil.speed *= newAttStatTable.gunRecoil.speed
			attStatTable.gunRecoil.punchMultiplier *= newAttStatTable.gunRecoil.punchMultiplier
		else
			attStatTable.gunRecoil = newAttStatTable.gunRecoil
		end
	end

	if newAttStatTable.aimFovDefault then -- change what zoom level you start at
		attStatTable.aimFovDefault = newAttStatTable.aimFovDefault -- Caution: this overrides whatever was there before. Only use one optic at a time!
	end

	if newAttStatTable.aimFovMin then -- change how much you can zoom in on your optic
		attStatTable.aimFovMin = newAttStatTable.aimFovMin -- Caution: this overrides whatever was there before. Only use one optic at a time!
	end

	-- adjust aimtime
	if newAttStatTable.aimTime then -- change how fast you can aim down sights
		if attStatTable.aimTime then
			attStatTable.aimTime *= newAttStatTable.aimTime
		else
			attStatTable.aimTime = newAttStatTable.aimTime
		end
	end

	if newAttStatTable.magazineCapacity then -- change how many rounds you can have in your magazine
		attStatTable.magazineCapacity = newAttStatTable.magazineCapacity -- Caution: this overrides whatever was there before. Only apply this property once!
	end

	if newAttStatTable.magazineExtension then -- use this property if you want to add a specific number of extra rounds rather than setting a new total, e.g. an extended floorplate
		attStatTable.magazineCapacity += newAttStatTable.magazineExtension
	end

	if newAttStatTable.maxAmmoPool then -- change how much ammo you can carry overall
		attStatTable.maxAmmoPool = newAttStatTable.maxAmmoPool -- Caution: This overrides whatever was there before. Only apply this property once!
	end

	if newAttStatTable.startAmmoPool then -- change how much ammo you start with
		attStatTable.startAmmoPool = newAttStatTable.startAmmoPool -- Caution: This overrides whatever was there before. Only apply this property once!
	end

	if newAttStatTable.damage then -- increment damage to certain body parts
		local function scaleDamageSlot(base, mult)
			if typeof(mult) ~= "number" then
				return base
			end
			if typeof(base) == "number" then
				return base * mult
			end
			if typeof(base) == "table" then
				if typeof(base.Min) == "number" then
					base.Min *= mult
				end
				if typeof(base.Max) == "number" then
					base.Max *= mult
				end
			end
			return base
		end

		if attStatTable.damage then
			attStatTable.damage.Head = scaleDamageSlot(attStatTable.damage.Head, newAttStatTable.damage.Head)
			attStatTable.damage.Torso = scaleDamageSlot(attStatTable.damage.Torso, newAttStatTable.damage.Torso)
			attStatTable.damage.Other = scaleDamageSlot(attStatTable.damage.Other, newAttStatTable.damage.Other)
		else
			attStatTable.damage = newAttStatTable.damage
		end
	end

	if newAttStatTable.muzzleVelocity then -- use this property if you're increasing or decreasing muzzle velocity by a % (different barrels, rifling types)
		if attStatTable.muzzleVelocity then
			attStatTable.muzzleVelocity *= newAttStatTable.muzzleVelocity
		else
			attStatTable.muzzleVelocity = newAttStatTable.muzzleVelocity
		end
	end

	if newAttStatTable.muzzleVelocityReplace then -- use this property if you're replacing muzzle velocity altogether (e.g. swapping calibers)
		attStatTable.muzzleVelocityReplace = newAttStatTable.muzzleVelocityReplace -- Caution: This overrides whatever was there before. Only apply this property once!
	end

	if newAttStatTable.tracers then -- use this property for different tracer colors
		attStatTable.tracers = newAttStatTable.tracers -- Caution: This overrides whatever was there before. Only apply this property once!
		attStatTable.tracerTiming = newAttStatTable.tracerTiming -- Caution: This overrides whatever was there before. Only apply this property once!
		attStatTable.tracerColor = newAttStatTable.tracerColor -- Caution: This overrides whatever was there before. Only apply this property once!
	end

	if newAttStatTable.explosiveAmmo then
		attStatTable.explosiveAmmo = newAttStatTable.explosiveAmmo -- Caution: This overrides whatever was there before. Only apply this property once!
		attStatTable.explosionEffect = newAttStatTable.explosionEffect -- Caution: This overrides whatever was there before. Only apply this property once!
		attStatTable.explosionRadius = newAttStatTable.explosionRadius -- Caution: This overrides whatever was there before. Only apply this property once!
	end

	if newAttStatTable.muzzleChance then
		attStatTable.muzzleChance = newAttStatTable.muzzleChance -- Caution: This overrides whatever was there before. Only apply this property once!
	end
	
	if newAttStatTable.ammoType then
		attStatTable.ammoType = newAttStatTable.ammoType -- Caution: This overrides whatever was there before. Only apply this property once!
	end
	
	local newAttModel = assets.Attachments[attachment]:FindFirstChild("AttachmentModel")
	if newAttModel then
		if newAttModel.Main:FindFirstChild("Muzzle") then
			attStatTable.newMuzzleDevice = attachment -- Caution: This overrides whatever was there before. Only apply this property once!
		end

		if newAttModel.Main:FindFirstChild("Fire") then
			attStatTable.newFireSound = true
		end

		if newAttModel.Main:FindFirstChild("Laser") then
			attStatTable.laserOrigin = attachment -- Caution: This overrides whatever was there before. Only apply this property once!
		end

		if newAttModel.Main:FindFirstChild("Bipod") then
			attStatTable.Bipod = attachment -- Caution: This overrides whatever was there before. Only apply this property once!
		end
	end

	return attStatTable
end

-- recursively apply sub attachments
local function applyRecursiveAttachments(attStatTable, attachmentData)
	if not attachmentData or attachmentData == "" then return attStatTable end

	if typeof(attachmentData) == "string" then
		attStatTable = applyAttachmentData(attStatTable, attachmentData)

	elseif typeof(attachmentData) == "table" then
		local subAttachment = attachmentData[1]
		local subAttachmentNodes = attachmentData[2]
		applyAttachmentData(attStatTable, subAttachment)
		for item, name in pairs(subAttachmentNodes) do
			applyRecursiveAttachments(attStatTable, name)
		end
	end

	return attStatTable
end

gunsmith.placeAttachment = function(weapon, attachmentSlot, weaponAttachment, parentPart) -- place an attachment on a weapon
	local attac = assets.Attachments:FindFirstChild(weaponAttachment)
	if not attac then 
		warn("Model for "..weaponAttachment.." not found") return end
	local newAttachment = assets.Attachments[weaponAttachment].AttachmentModel:Clone()
	newAttachment.Parent = weapon
	newAttachment.Name = weaponAttachment

	if newAttachment.PrimaryPart then
		newAttachment:SetPrimaryPartCFrame(parentPart[attachmentSlot].CFrame)
		weldMod.WeldModel(newAttachment,parentPart[attachmentSlot],false)
	else
		warn("Attachment "..weaponAttachment.." has no PrimaryPart and cannot be positioned properly!")
	end

	if newAttachment.Main:FindFirstChild("Muzzle") then
		weapon.Grip.Muzzle.WorldCFrame = newAttachment.Main.Muzzle.WorldCFrame
	end
	
	return newAttachment
end

gunsmith.getAttStats = function(weaponAttachments, currentWeapon) -- get all attachment data for weapon (used when calling up wepstats for data, e.g. adjusting rate of fire, calculating damage and velocity modifications)
	local attStats = {}
	if not weaponAttachments then return end
	for slot, attachmentData in pairs(weaponAttachments) do
		attStats = applyRecursiveAttachments(attStats, attachmentData, currentWeapon)
	end
	
	if currentWeapon then
		for slot, item in pairs(currentWeapon:GetChildren()) do -- using a for loop instead of name accounts for non-unique names e.g. multiple flashlights
			if item:IsA("Model") then
				if item:FindFirstChild("Main") and item.Main:FindFirstChild("Flashlight") then
					if not attStats.flashlights_server then
						attStats.flashlights_server = {}
					end
					table.insert(attStats.flashlights_server, item)
				end
			end
		end
	end

	return attStats
end

return gunsmith