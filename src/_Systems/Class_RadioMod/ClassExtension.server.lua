local ClassAPI = require("@game/ServerScriptService/Class_Server/ClassAPI")

if not ClassAPI.IsLoaded() then
    ClassAPI.OnLoaded:Wait()
end

for _, itemProvider in ipairs(script.Parent.ItemProviders:GetChildren()) do
    local provider = require(itemProvider)
    ClassAPI.RegisterItemProvider(provider)
end