local runtime = require("@game/ServerScriptService/Faction_Server/RuntimeLocator").GetRuntime()

for _, itemProvider in ipairs(script.Parent.ItemProviders:GetChildren()) do
    local provider = require(itemProvider)
    runtime:RegisterItemProvider(provider)
end