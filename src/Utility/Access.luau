--!strict

local CollectionService = game:GetService("CollectionService")

local DEFAULT_WAIT_TIMEOUT = 5

export type CreateOptions = {
	assetsTag: string,
	configTag: string,
	waitTimeout: number?,
}

export type Access<TConfig> = {
	Assets: Folder,
	Config: TConfig,
}

local Access = {}

function Access.resolveSingleTaggedInstance(tagName: string, waitTimeout: number?): Instance
	local timeout = if waitTimeout ~= nil then waitTimeout else DEFAULT_WAIT_TIMEOUT
	local instances = CollectionService:GetTagged(tagName)

	if #instances == 0 and timeout > 0 then
		local deadline = os.clock() + timeout
		while #instances == 0 and os.clock() < deadline do
			task.wait(math.max(0, math.min(0.1, deadline - os.clock())))
			instances = CollectionService:GetTagged(tagName)
		end
	end

	if #instances == 0 then
		local suffix = if timeout > 0 then ` after {timeout}s` else ""
		error(`{tagName} tag not found{suffix}`)
	end
	if #instances > 1 then
		warn(`{tagName} tag found {#instances} times - tag only one instance with {tagName}.`)
	end

	return instances[1]
end

function Access.create<TConfig>(options: CreateOptions): Access<TConfig>
	local configModule = Access.resolveSingleTaggedInstance(options.configTag, options.waitTimeout)
	if not configModule:IsA("ModuleScript") then
		error(`{options.configTag} tag must resolve to a ModuleScript`)
	end

	local assets = Access.resolveSingleTaggedInstance(options.assetsTag, options.waitTimeout)
	if not assets:IsA("Folder") then
		error(`{options.assetsTag} tag must resolve to a Folder`)
	end

	return table.freeze({
		Assets = assets :: Folder,
		Config = require(configModule) :: TConfig,
	}) :: Access<TConfig>
end

return Access
