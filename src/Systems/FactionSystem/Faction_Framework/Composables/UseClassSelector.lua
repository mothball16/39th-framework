--[[
composable that provides class indexes
]]

local Types = require("../Core/Types")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
const GetPlayerSlice = require("../Selectors/GetPlayerSlice")
local source = Vide.source
local effect = Vide.effect
local derive = Vide.derive
local untrack = Vide.untrack
return function(playerSlice: GetPlayerSlice.PlayerSlice)
	local classIndex = source(1)
	-- dirty is set to false externally when the appropriate action is taken
	local dirty = source(false)

	-- keep class index aligned with server assignment
	effect(function()
		playerSlice.factionId()
		playerSlice.groupKey()

		local id = untrack(playerSlice.classId)
		local classes = untrack(playerSlice.classes)
		local index = 1
		for i, class in classes do
			if class.Id == id then
				index = i
				break
			end
		end
		classIndex(index)
	end)

	-- set the dirty flag when anything changes, just to be safe
	effect(function()
		playerSlice.factionId()
		playerSlice.groupKey()
		classIndex()
		dirty(true)
	end)

	-- on load, faction/group/class might be missing, check to make sure they are all present
	local selectedClass: () -> Types.ClassDescriptor? = derive(function()
		if not playerSlice.factionId() or not playerSlice.groupKey() or not playerSlice.classes() then
			return nil
		end

		local classes = playerSlice.classes()
		if #classes == 0 then
			return nil
		end
		return classes[math.clamp(classIndex(), 1, #classes)]
	end)

	local function cycleClass(offset: number)
		local classes = playerSlice.classes()
		if #classes <= 1 then
			return
		end
		local nextIndex = ((classIndex() - 1 + offset) % #classes) + 1
		classIndex(nextIndex)
	end

	return {
		dirty = dirty,
		classIndex = classIndex,
		selectedClass = selectedClass,
		cycleClass = cycleClass,
	}
end
