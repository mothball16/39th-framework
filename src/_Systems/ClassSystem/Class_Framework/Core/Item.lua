local AccessoryProvider = require("../ItemProviders/Accessory")
local TestProvider = require("../ItemProviders/Test")
local ToolProvider = require("../ItemProviders/Tool")
local UniformProvider = require("../ItemProviders/Uniform")

local Item = {}

function Item.accessory(itemArgs: AccessoryProvider.BuildArgs): AccessoryProvider.ItemArgs
    return AccessoryProvider.Build(itemArgs)
end

function Item.test(itemArgs: TestProvider.BuildArgs): TestProvider.ItemArgs
    return TestProvider.Build(itemArgs)
end

function Item.tool(itemArgs: ToolProvider.BuildArgs): ToolProvider.ItemArgs
    return ToolProvider.Build(itemArgs)
end

function Item.uniform(itemArgs: UniformProvider.BuildArgs): UniformProvider.ItemArgs
    return UniformProvider.Build(itemArgs)
end


return Item
