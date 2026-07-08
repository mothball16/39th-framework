--!strict
local RuntimeLocator = {}

local runtime: any = nil

function RuntimeLocator.LoadRuntime(nextRuntime: any)
	runtime = nextRuntime
end

function RuntimeLocator.GetRuntime(): any
	return runtime
end

return RuntimeLocator
