local ReplicatedStorage = game:GetService("ReplicatedStorage")
local assets = ReplicatedStorage:WaitForChild("SPH_Assets")
local configs = assets:WaitForChild("Configurations")

local WeaponStatLocator = {}

local function getConfig(sphWeapon, configName)
	local attr = sphWeapon:GetAttribute("SPH_" .. configName)
	if attr then
		local folder = configs:FindFirstChild(configName)
		local module = folder and folder:FindFirstChild(attr)
		if module then return table.freeze(require(module)) end
	end

	local direct = sphWeapon:FindFirstChild(configName)
	if direct then
        warn(`using fallback config method for {sphWeapon.Parent.Name}. switch to storing configs in SPH_Assets.Configurations`)
        return table.freeze(require(direct))
    end

	warn(`no {configName} found for {sphWeapon.Parent.Name}`)
	return nil
end

function WeaponStatLocator.getWeaponStats(sphWeapon)
	return getConfig(sphWeapon, "WeaponStats")
end

function WeaponStatLocator.getBulletPhysics(sphWeapon)
	return getConfig(sphWeapon, "BulletPhysics")
end

return WeaponStatLocator