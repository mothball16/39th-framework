--[[
composable that provides variant indexes
]]

local Types = require("../Core/Types")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local GetPlayerSlice = require("../Selectors/GetPlayerSlice")
local source = Vide.source
local effect = Vide.effect
local derive = Vide.derive
local untrack = Vide.untrack
return function(playerSlice: GetPlayerSlice.PlayerSlice)
	local variantIndex = source(1)
	-- dirty is set to false externally when the appropriate action is taken
	local dirty = source(false)

	-- keep variant index aligned with server assignment
	effect(function()
		playerSlice.factionId()
		playerSlice.classKey()

		local id = untrack(playerSlice.variantId)
		local variants = untrack(playerSlice.variants)
		local index = 1
		for i, variant in variants do
			if variant.Id == id then
				index = i
				break
			end
		end
		variantIndex(index)
	end)

	-- on load, faction/class/variant might be missing, check to make sure they are all present
	local selectedVariant: () -> Types.VariantDescriptor? = derive(function()
		if not playerSlice.factionId() or not playerSlice.classKey() or not playerSlice.variants() then
			return nil
		end

		local variants = playerSlice.variants()
		if #variants == 0 then
			return nil
		end
		return variants[math.clamp(variantIndex(), 1, #variants)]
	end)

	local function cycleVariant(offset: number)
		local variants = playerSlice.variants()
		if #variants <= 1 then
			return
		end
		local nextIndex = ((variantIndex() - 1 + offset) % #variants) + 1
		variantIndex(nextIndex)
		dirty(true)
	end

	return {
		dirty = dirty,
		variantIndex = variantIndex,
		selectedVariant = selectedVariant,
		cycleVariant = cycleVariant,
	}
end
