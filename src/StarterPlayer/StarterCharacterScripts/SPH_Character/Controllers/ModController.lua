local ModController = {}
local mods = {}

function ModController.Initialize(params)
	local modsFolder = script.Parent.Parent:FindFirstChild("Mods")
	if not modsFolder then return end

	for _, modModule in ipairs(modsFolder:GetChildren()) do
		if modModule:IsA("ModuleScript") then
			local mod = require(modModule)
			table.insert(mods, mod)
			if mod.Initialize then
				mod.Initialize(params)
			end
		end
	end
end

function ModController.UpdateRender(dt)
	for _, mod in ipairs(mods) do
		if mod.UpdateRender then
			mod.UpdateRender(dt)
		end
	end
end

function ModController.UpdateHeartbeat(dt)
	for _, mod in ipairs(mods) do
		if mod.UpdateHeartbeat then
			mod.UpdateHeartbeat(dt)
		end
	end
end

return ModController