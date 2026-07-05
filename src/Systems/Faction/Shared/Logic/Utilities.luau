local Utilities = {}

export type PlayerKey = string

function Utilities.ToPlayerKey(userId: number | string): PlayerKey
	if type(userId) == "number" then
		return tostring(userId)
	end
	return userId
end

function Utilities.Report(result: boolean, message: string?, action: string?): (boolean, string?)
	if not action then
		local name = debug.info(2, "n")
		local source = debug.info(2, "s")
		local line = debug.info(2, "l")
		if name and name ~= "" then
			action = `{name} @ {source}:{line}`
		else
			action = `{source}:{line}`
		end
	end

	if message and message == "" then
		message = nil
	end

	if result and message then
		print(`[{action}] success w/ msg: {message}`)
	elseif not result then
		warn(`[{action}] failure: {message or "unknown"}`)
	end

	return result, message
end

return Utilities
