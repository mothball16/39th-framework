local attachmentLoader = {}

--< Services >--
local RS: ReplicatedStorage = game:GetService("ReplicatedStorage")

--< Assets >--
local sph = require(RS.SPH_Framework.Core.GameAccess)
local assets = sph.assets
local attachments = assets.Attachments

attachmentLoader.Attachments = {}

for _, folder in ipairs(attachments:GetChildren()) do
	if not folder or not folder:IsA("Folder") then continue end
	
	local statsModule: ModuleScript = folder:FindFirstChild("AttStats")
	local attStats: {any} = statsModule and require(statsModule)
	if not statsModule or not attStats then continue end
	
	attStats.type = attStats.type or "Universal"
	
	if not attachmentLoader.Attachments[attStats.type] then attachmentLoader.Attachments[attStats.type] = {} end
	if attachmentLoader.Attachments[attStats.type][folder.Name] then continue end
	
	table.insert(attachmentLoader.Attachments[attStats.type], folder.Name)
end

return attachmentLoader
