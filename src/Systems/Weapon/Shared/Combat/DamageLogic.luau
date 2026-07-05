--[[
	Bullet damage from WeaponStats.damage + WeaponStats.range.

	New: damage.Head / Torso / Other = { Min = low, Max = high } (either order OK).
	range.Min .. range.Max = stud distance where damage goes from high (close) to low (far).

	Old configs: per-part numbers, same as before.
]]

local DamageLogic = {}

DamageLogic.Zones = {
	Head = "Head",
	Torso = "Torso",
	Other = "Other",
	None = "None",
}

DamageLogic.ZoneByPartName = {
	["Head"] = DamageLogic.Zones.Head,
	["Torso"] = DamageLogic.Zones.Torso,
	["HumanoidRootPart"] = DamageLogic.Zones.Torso,
	["Left Arm"] = DamageLogic.Zones.Other,
	["Right Arm"] = DamageLogic.Zones.Other,
	["Left Leg"] = DamageLogic.Zones.Other,
	["Right Leg"] = DamageLogic.Zones.Other,

	["UpperTorso"] = DamageLogic.Zones.Torso,
	["LeftUpperArm"] = DamageLogic.Zones.Other,
	["RightUpperArm"] = DamageLogic.Zones.Other,
	["LeftLowerArm"] = DamageLogic.Zones.Other,
	["RightLowerArm"] = DamageLogic.Zones.Other,
	["LeftUpperLeg"] = DamageLogic.Zones.Other,
	["RightUpperLeg"] = DamageLogic.Zones.Other,
	["LeftLowerLeg"] = DamageLogic.Zones.Other,
}

function DamageLogic.getZone(partName: string): string
	if DamageLogic.ZoneByPartName[partName] then
		return DamageLogic.ZoneByPartName[partName]
	end
	return DamageLogic.Zones.None
end

--- High damage at/under range.Min, low damage at/over range.Max, linear between.
function DamageLogic.getDamage(damageStats: any, hitPartName: string, distance: number?, weaponRange: any): number
	if typeof(damageStats) ~= "table" then
		return 0
	end

	local z = damageStats[DamageLogic.getZone(hitPartName)]
	if typeof(z) == "table" and typeof(z.Min) == "number" and typeof(z.Max) == "number" then
		local low = math.min(z.Min, z.Max)
		local high = math.max(z.Min, z.Max)

		if typeof(weaponRange) ~= "table" or typeof(weaponRange.Min) ~= "number" or typeof(weaponRange.Max) ~= "number" or distance == nil then
			return low
		end
		local r0 = math.min(weaponRange.Min, weaponRange.Max)
		local r1 = math.max(weaponRange.Min, weaponRange.Max)

		if r1 <= r0 then
			if distance <= r0 then
				return high
			end
			return low
		end

		local d = math.clamp(distance, r0, r1)
		return math.map(d, r0, r1, high, low)
	end

	-- Legacy
	local n = damageStats[hitPartName]
	if typeof(n) == "number" then
		return n
	end
	if hitPartName == "HumanoidRootPart" then
		if typeof(damageStats.UpperTorso) == "number" then
			return damageStats.UpperTorso
		end
		if typeof(damageStats.Torso) == "number" then
			return damageStats.Torso
		end
	end
	if typeof(damageStats.Other) == "number" then
		return damageStats.Other
	end
	return 0
end

return DamageLogic