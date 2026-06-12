local Utilities = {}

function Utilities.Report(result: boolean, message: string?): (boolean, string?)
    if result and message and message ~= "" then
        print(`success: {message}`)
    else
        warn(`failure: {message or "unknown"}`)
    end
    return result, message
end

return Utilities
