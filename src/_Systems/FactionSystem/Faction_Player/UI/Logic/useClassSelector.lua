--[[
composable that provides class indexes
]]

local Types = require("@game/ReplicatedStorage/Faction_Framework/Core/Types")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local source = Vide.source
local effect = Vide.effect
local derive = Vide.derive

return function(factionId: () -> string?, groupKey: () -> string?, classes: () -> { Types.ClassDescriptor })
    local classIndex = source(1)
    -- dirty is set to false externally when the appropriate action is taken
    local dirty = source(false)

    -- reset the class index when the faction id or group key changes
    effect(function()
        factionId()
        groupKey()
        classIndex(1)
    end)

    -- set the dirty flag when anything changes, just to be safe
    effect(function()
        factionId()
        groupKey()
        classIndex()
        dirty(true)
    end)

    -- on load, faction/group/class might be missing, check to make sure they are all present
	local selectedClass: () -> Types.ClassDescriptor? = derive(function()
        if not factionId() or not groupKey() or not classes() then
            return nil
        end
        
		local classes = classes()
		if #classes == 0 then
            warn("no classes found")
			return nil
		end
		return classes[math.clamp(classIndex(), 1, #classes)]
	end)


    local function cycleClass(offset: number)
        local classes = classes()
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