local Method = {}
Method.aimpartZOffset = .5 -- default acs behavior

local camera = workspace.CurrentCamera

-- check if the game is using this acs
function Method.autoDetectMethod()
	-- this is the default script so it shouldnt change anything
	return false
end

-- detect gun model for ChildAdded and ChildRemoved
function Method.modelDetectionPath()
	return camera
end

function Method.modelDetectionMethod(obj)
	if obj:IsA("Model") then
		local gunModel = obj:FindFirstChildOfClass("Model")
		
		if gunModel then
			return gunModel
		end
	end

	return nil
end

-- i set the parent of the SCOPE_FOCUS part to workspace
-- since it causes less lag when changing properties
function Method.parentingMethod(scopeFocusPart: Instance)
	scopeFocusPart.Parent = workspace
end

return Method