--!strict
--[[
renders and tears down world-space ping tag instances
client state should connect ping lifetime to this module
]]

local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local useAtom = require("@game/ReplicatedStorage/Packages/vide-charm").useAtom
local Vide = require("@game/ReplicatedStorage/Packages/Vide")

local create = Vide.create
local mount = Vide.mount

local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local PingTag = require("../UI/Roots/PingTag")

type PingInstanceProps = Types.PingTagProps & { size: Charm.Atom<UDim2> }

export type CleanupFunction = () -> ()

local PingTagRenderer = {}

local _ownedPings: {[Player]: {instance: BasePart, cleanup: CleanupFunction}} = {}


-- builds a ping tag without any state registration
function PingTagRenderer.CreatePingTag(owner: Instance, position: Vector3, props: PingInstanceProps): (CleanupFunction, BasePart)
	local container = Instance.new("Part")
	container.Name = "PingContainer"
	container.Parent = workspace
	container.Size = Vector3.new(0.1, 0.1, 0.1)
	container.Position = position
	container.CanCollide = false
	container.CanQuery = false
	container.Transparency = 1
	container.Anchored = true
	container.Massless = true
	local unmount = mount(function()
		return create "BillboardGui" {
			AlwaysOnTop = true,
			Size = useAtom(props.size),
			PingTag({
				imageId = props.imageId,
				name = props.name,
			})
		}
	end, container)

	return function()
		unmount()
		container:Destroy()
	end, container
end

function PingTagRenderer.GetPingTag(owner: Player)
	return _ownedPings[owner]
end

-- clears, builds and registers a ping tag
function PingTagRenderer.RegisterPingTag(owner: Player, position: Vector3, props: PingInstanceProps): Instance
	PingTagRenderer.DeletePingTag(owner)

	local cleanup, instance = PingTagRenderer.CreatePingTag(owner, position, props)
	_ownedPings[owner] = {
        owner = owner,
		instance = instance,
		cleanup = cleanup,
	}

	return instance
end

-- deletes a ping tag from the owned ping list
function PingTagRenderer.DeletePingTag(owner: Player)
	local data = _ownedPings[owner]
	if data and data.cleanup then
		data.cleanup()
	end
	_ownedPings[owner] = nil
end

return PingTagRenderer
