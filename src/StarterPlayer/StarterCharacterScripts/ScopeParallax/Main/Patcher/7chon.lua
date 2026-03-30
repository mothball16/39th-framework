local Method = {}
Method.aimpartZOffset = .5 -- default acs behavior
Method._7CHON_CLIENT_SCRIPT_NAME = "ACS_Clientv2"
Method._7CHON_NEW_VERSION_IDENTIFIER = "Debugs"

local StarterPlayer = game:GetService("StarterPlayer")
local StarterCharacterScripts = StarterPlayer.StarterCharacterScripts
local Default = require(script.Parent:WaitForChild("Default"))
local camera = workspace.CurrentCamera

-- check if the game is using this acs
function Method.autoDetectMethod()
	local saude = StarterCharacterScripts:FindFirstChild("Saude")
	if saude then
		local _7chonClientScript = saude:FindFirstChild(Method._7CHON_CLIENT_SCRIPT_NAME)
		if _7chonClientScript then
			-- only 1.2.3+ has this
			local _7chonDebugs = _7chonClientScript:FindFirstChild(Method._7CHON_NEW_VERSION_IDENTIFIER)
			if _7chonDebugs then
				return script.Name
			end
		end
	end
end

-- use default
Method.modelDetectionPath = Default.modelDetectionPath
Method.modelDetectionMethod = Default.modelDetectionMethod

function Method.parentingMethod(scopeFocusPart: Instance)
	task.spawn(function()
		repeat task.wait() until scopeFocusPart:FindFirstChildWhichIsA("Motor6D") -- не знаю почему
		scopeFocusPart.Parent = workspace
	end)
end

return Method