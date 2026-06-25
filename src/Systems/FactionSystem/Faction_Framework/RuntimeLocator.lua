--!strict
--[[
typed runtime singleton locator
]]

local Signal = require("@game/ReplicatedStorage/Packages/signal")

export type Locator<T> = {
	OnLoaded: typeof(Signal.new()),
	LoadRuntime: (runtime: T) -> (),
	GetRuntime: () -> T,
}

return function<T>(): Locator<T>
	local OnLoaded = Signal.new()
	local _runtime: T? = nil

	return {
		OnLoaded = OnLoaded,
		LoadRuntime = function(runtime: T)
			if _runtime ~= nil then
				error("RuntimeLocator already initialized")
			end
			_runtime = runtime
			OnLoaded:Fire()
		end,
		GetRuntime = function(): T
			if _runtime == nil then
				OnLoaded:Wait()
			end
			return _runtime :: T
		end,
	}
end
