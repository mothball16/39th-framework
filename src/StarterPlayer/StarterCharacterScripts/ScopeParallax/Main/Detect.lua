local Detect = {}
Detect.timeout = 5

local Patcher = require(script.Parent:WaitForChild("Patcher"))

function Detect.init()
	local rate = 0
	local modules = {}
	
	for _, module in script.Parent.Patcher:GetChildren() do
		table.insert(modules, require(module).autoDetectMethod)
	end
	
	task.spawn(function() -- silent detect
		while true do
			if rate >= Detect.timeout then return end
			rate += task.wait()
			
			for _, autoDetect in modules do
				local customMethod = autoDetect()
				if customMethod then
					Patcher.update(customMethod)
					return
				end
			end
		end
	end)
end

return Detect
