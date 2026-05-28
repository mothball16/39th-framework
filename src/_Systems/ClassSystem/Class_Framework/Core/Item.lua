local AccessoryProvider = require("../ItemProviders/Accessory")
local TestProvider = require("../ItemProviders/Test")
local ToolProvider = require("../ItemProviders/Tool")
local UniformProvider = require("../ItemProviders/Uniform")

local Item = {}

function Item.accessory(args: AccessoryProvider.BuildArgs): AccessoryProvider.ItemArgs
    return AccessoryProvider.Build(args)
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
