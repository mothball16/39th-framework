local Framework = script:FindFirstAncestor("SPH_Framework")
local Access = require(Framework.Access)
local assets = Access.assets
local configs = assets:WaitForChild("Configurations")

local Types = require("@game/ReplicatedStorage/SPH_Framework/Core/ConfigurationTypes")

local WeaponStatLocator = {}

local function getConfig(sphWeapon, configName)
	local attr = sphWeapon:GetAttribute("SPH_" .. configName)
	if attr then
		if attr == "#name" then
			attr = sphWeapon.Parent.Name
		end

		local folder = configs:FindFirstChild(configName)
		local module = folder and folder:FindFirstChild(attr)
		if module then
            local tbl = require(module)
            if not table.isfrozen(tbl) then
                tbl = table.freeze(tbl)
            end
            return tbl
        end
	end

	local direct = sphWeapon:FindFirstChild(configName)
	if direct then
        warn(`using fallback config method for {sphWeapon.Parent.Name}. switch to storing configs in SPH_Assets.Configurations`)
        return require(direct)
    end



	warn(`no {configName} found for {sphWeapon.Parent.Name}`)
	return nil
end

function WeaponStatLocator.getWeaponStats(sphWeapon): () -> Types.WeaponStats
	return getConfig(sphWeapon, "WeaponStats")
end

function WeaponStatLocator.getBulletPhysics(sphWeapon)
	return getConfig(sphWeapon, "BulletPhysics")
end

return WeaponStatLocator