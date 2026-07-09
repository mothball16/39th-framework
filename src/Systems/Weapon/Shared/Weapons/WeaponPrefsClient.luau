-- Per-tool session prefs (client memory) + apply from store on equip.
-- isApplying suppresses duplicate remote fires from Charm subscribers during bulk apply.
-- TODO: this some ai slop and needs to be cleaned up

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = ReplicatedStorage.Systems.Weapon
local Access = require(Framework.Access)
local config = Access.Config
local NetworkEvents = require(Framework.Network.NetworkEvents)
local P = NetworkEvents.packets

local WeaponPrefsClient = {
	isApplying = false,
	_applyDepth = 0,
	_byWeaponName = {},
	_global = {
		aimSens = config.defaultAimSensitivity,
	},
}

function WeaponPrefsClient.getGlobal(pref)
	return WeaponPrefsClient._global[pref]
end

function WeaponPrefsClient.setGlobal(pref, value)
	WeaponPrefsClient._global[pref] = value
end

function WeaponPrefsClient.get(weaponName)
	return WeaponPrefsClient._byWeaponName[weaponName]
end

function WeaponPrefsClient.set(weaponName, prefs)
	WeaponPrefsClient._byWeaponName[weaponName] = prefs
end

function WeaponPrefsClient.beginApply()
	WeaponPrefsClient._applyDepth += 1
	WeaponPrefsClient.isApplying = true
end

function WeaponPrefsClient.endApply()
	WeaponPrefsClient._applyDepth = math.max(0, WeaponPrefsClient._applyDepth - 1)
	WeaponPrefsClient.isApplying = WeaponPrefsClient._applyDepth > 0
end

local function findChildModelWithMainPartChild(gun, partName)
	if not gun then
		return nil
	end
	for _, child in ipairs(gun:GetChildren()) do
		if child:IsA("Model") then
			local main = child:FindFirstChild("Main")
			if main and main:FindFirstChild(partName) then
				return child
			end
		end
	end
	return nil
end

local function getLaserAttachmentPoint(model)
	if not model then
		return nil
	end
	local mount = findChildModelWithMainPartChild(model, "Laser")
	if mount then
		return mount.Main:FindFirstChild("Laser")
	end
	local grip = model:FindFirstChild("Grip")
	if grip then
		return grip:FindFirstChild("Laser")
	end
	return nil
end

local function weaponHasFlashlightClient(gun)
	if not gun or not gun.Grip then
		return false
	end
	if gun.Grip:FindFirstChild("Flashlight") then
		return true
	end
	return findChildModelWithMainPartChild(gun, "Flashlight") ~= nil
end

local function weaponHasBipodClient(gun)
	if not gun then
		return false
	end
	return findChildModelWithMainPartChild(gun, "Bipod") ~= nil
end

local function fireModeSupported(mode, wepStats)
	if type(mode) ~= "number" or mode % 1 ~= 0 or mode < 0 or mode > 5 or mode == 4 then
		return false
	end
	local fs = wepStats and wepStats.fireSwitch
	return fs and fs[mode] ~= nil and fs[mode] ~= false
end

local function sightIndexSupported(idx, gun)
	if type(idx) ~= "number" or idx % 1 ~= 0 or idx < 1 or idx > 8 then
		return false
	end
	local name = "AimPart" .. idx
	if gun:FindFirstChild(name) then
		return true
	end
	if idx == 1 and gun:FindFirstChild("AimPart") then
		return true
	end
	return false
end

function WeaponPrefsClient.applyPersisted(weaponName, State, WeaponState, WC)
	local prefs = WeaponPrefsClient.get(weaponName)
	if not prefs or not State.equippedTool() then
		return
	end
	local gun = WeaponState.gunModel()
	if not gun then
		return
	end

	local baselineFireMode = WeaponState.fireMode()
	local wepStats = WeaponState.wepStats()
	local validated = {}

	for key, val in pairs(prefs) do
		if key == "laserEnabled" and getLaserAttachmentPoint(gun) then
			validated.laserEnabled = val
		elseif key == "flashlightEnabled" and weaponHasFlashlightClient(gun) then
			validated.flashlightEnabled = val
		elseif key == "bipodEnabled" and weaponHasBipodClient(gun) then
			validated.bipodEnabled = val
		elseif key == "fireMode" and fireModeSupported(val, wepStats) then
			validated.fireMode = val
		elseif key == "sightIndex" and sightIndexSupported(val, gun) then
			validated.sightIndex = val
		end
	end

	local pruned = {}
	for k in pairs(prefs) do
		if validated[k] ~= nil then
			pruned[k] = validated[k]
		end
	end
	WeaponPrefsClient.set(weaponName, pruned)

	if next(validated) == nil then
		return
	end

	WeaponPrefsClient.beginApply()

	if validated.sightIndex then
		WeaponState.sightIndex(validated.sightIndex)
	end
	if validated.fireMode ~= nil then
		WeaponState.fireMode(validated.fireMode)
		local t = State.equippedTool()
		if t then
			t.FireMode.Value = validated.fireMode
		end
		if validated.fireMode ~= baselineFireMode then
			P.SwitchFireMode.send({ mode = validated.fireMode })
		end
	end
	if validated.flashlightEnabled ~= nil then
		WeaponState.flashlightEnabled(validated.flashlightEnabled)
		P.PlayerToggleAttachment.send({ attachmentType = 0, enabled = validated.flashlightEnabled })
	end
	if validated.laserEnabled ~= nil then
		WeaponState.laserEnabled(validated.laserEnabled)
		P.PlayerToggleAttachment.send({ attachmentType = 1, enabled = validated.laserEnabled })
	end
	if validated.bipodEnabled ~= nil then
		WeaponState.bipodEnabled(validated.bipodEnabled)
		P.PlayerToggleAttachment.send({ attachmentType = 2, enabled = validated.bipodEnabled })
	end

	WC:UpdateAttachmentsVisibility()
	WeaponPrefsClient.endApply()
end

return WeaponPrefsClient
