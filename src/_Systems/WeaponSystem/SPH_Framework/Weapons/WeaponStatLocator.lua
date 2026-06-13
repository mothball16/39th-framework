local Framework = script:FindFirstAncestor("SPH_Framework")
local Access = require(Framework.Access)
local assets = Access.assets
local configs = assets:WaitForChild("Configurations")

local Types = require("@game/ReplicatedStorage/SPH_Framework/Core/ConfigurationTypes")

local WeaponStatLocator = {}

local function getConfig(tool, configName)
	local attr = tool:GetAttribute("SPH_" .. configName)
	if attr then
		if attr == "#name" then
			attr = tool.Name
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

	warn(`no {configName} found for {tool.Name}`)
	return nil
end

function WeaponStatLocator.getWeaponStats(tool): Types.WeaponStats?
	return getConfig(tool, "WeaponStats")
end

function WeaponStatLocator.getBulletPhysics(tool)
	return getConfig(tool, "BulletPhysics")
end

return WeaponStatLocator
