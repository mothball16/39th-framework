local Framework = script:FindFirstAncestor("Weapon")
local Access = require(Framework.Access)
local assets = Access.Assets
local configs = assets:WaitForChild("Configurations")

local Types = require("@game/ReplicatedStorage/Systems/Weapon/Core/ConfigurationTypes")

local WeaponStatLocator = {}

local function resolveConfigModule(configName, moduleName)
	local folder = configs:FindFirstChild(configName)
	local module = folder and folder:FindFirstChild(moduleName)
	if module then
		local tbl = require(module)
		if not table.isfrozen(tbl) then
			tbl = table.freeze(tbl)
		end
		return tbl
	end
	return nil
end

local function getConfig(tool, configName)
	local attr = tool:GetAttribute("SPH_" .. configName)
	if attr then
		if attr == "#name" then
			attr = tool.Name
		end

		local tbl = resolveConfigModule(configName, attr)
		if tbl then
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
	local wepStats = WeaponStatLocator.getWeaponStats(tool)
	if not wepStats or not wepStats.bulletPhysics then
		return nil
	end

	local physics = resolveConfigModule("BulletPhysics", wepStats.bulletPhysics)
	if not physics then
		warn(`no BulletPhysics found for {wepStats.bulletPhysics} ({tool.Name})`)
	end
	return physics
end

return WeaponStatLocator
