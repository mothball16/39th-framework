local AccessoryProvider = require("../ItemProviders/Accessory")
local CallbackProvider = require("../ItemProviders/Callback")
local MaxHealthProvider = require("../ItemProviders/MaxHealth")
local SpeedProvider = require("../ItemProviders/Speed")
local TestProvider = require("../ItemProviders/Test")
local ToolProvider = require("../ItemProviders/Tool")
local UniformProvider = require("../ItemProviders/Uniform")

local Item = {}

function Item.accessory(args: AccessoryProvider.BuildArgs): AccessoryProvider.ItemArgs
	return AccessoryProvider.Build(args)
end

function Item.callback(args: CallbackProvider.BuildArgs): CallbackProvider.ItemArgs
	return CallbackProvider.Build(args)
end

function Item.maxHealth(args: MaxHealthProvider.BuildArgs): MaxHealthProvider.ItemArgs
	return MaxHealthProvider.Build(args)
end

function Item.speed(args: SpeedProvider.BuildArgs): SpeedProvider.ItemArgs
	return SpeedProvider.Build(args)
end

function Item.test(args: TestProvider.BuildArgs): TestProvider.ItemArgs
	return TestProvider.Build(args)
end

function Item.tool(args: ToolProvider.BuildArgs): ToolProvider.ItemArgs
	return ToolProvider.Build(args)
end

function Item.uniform(args: UniformProvider.BuildArgs): UniformProvider.ItemArgs
	return UniformProvider.Build(args)
end

return Item
