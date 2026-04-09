local WeaponClientPersist = {
	_byWeaponName = {},
	isApplying = false,
	_applySeq = 0,
}

function WeaponClientPersist.get(weaponName)
	return WeaponClientPersist._byWeaponName[weaponName]
end

function WeaponClientPersist.set(weaponName, prefs)
	WeaponClientPersist._byWeaponName[weaponName] = prefs
end

function WeaponClientPersist.beginApply()
	WeaponClientPersist._applySeq += 1
	WeaponClientPersist.isApplying = true
end

function WeaponClientPersist.endApply()
	local currentSeq = WeaponClientPersist._applySeq
	task.defer(function()
		if WeaponClientPersist._applySeq == currentSeq then
			WeaponClientPersist.isApplying = false
		end
	end)
end

return WeaponClientPersist
