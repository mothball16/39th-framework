local Method = {}
Method.aimpartZOffset = 0
Method._SPEARHEAD_FOLDER_NAME = "SPH_Assets"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local camera = workspace.CurrentCamera
local Default = require(script.Parent:WaitForChild("Default"))

-- check if the game is using this acs
function Method.autoDetectMethod()
	local spearheadFolder = ReplicatedStorage:FindFirstChild(Method._SPEARHEAD_FOLDER_NAME)
	if spearheadFolder then
		return script.Name
	end
end

-- detect gun model for ChildAdded and ChildRemoved
function Method.modelDetectionPath()
	local weaponRig = camera:WaitForChild("WeaponRig")
	local weaponFolder = weaponRig:WaitForChild("Weapon")
	return weaponFolder
end

function Method.modelDetectionMethod(obj)
	return obj
end

-- use default
Method.parentingMethod = Default.parentingMethod

return Method