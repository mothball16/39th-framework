local TableUtil = require("@game/ReplicatedStorage/Packages/table-util")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local useAtom = require("@game/ReplicatedStorage/Packages/vide-charm").useAtom
local Vide = require("@game/ReplicatedStorage/Packages/Vide")

local create = Vide.create
local mount = Vide.mount

local Types = require("@game/ReplicatedStorage/Systems/Aware/Core/Types")
local PingTag = require("../UI/Roots/PingTag")

type PingInstanceProps = Types.PingTagProps & { size: Charm.Atom<UDim2> }

export type CleanupFunction = () -> ()

local PingController = {}

local _ownedPings: {[Player]: {instance: BasePart, cleanup: CleanupFunction}} = {}


-- builds a ping tag without any state registration
function PingController.CreatePingTag(owner: Instance, position: Vector3, props: PingInstanceProps): (CleanupFunction, Instance)
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

function PingController.GetPingTags()
	return _ownedPings
end

function PingController.GetPingTag(owner: Player)
	return _ownedPings[owner]
end

-- clears, builds and registers a ping tag with the controller
function PingController.RegisterPingTag(owner: Player, position: Vector3, props: PingInstanceProps): Instance
	PingController.DeletePingTag(owner)

	local cleanup, instance = PingController.CreatePingTag(owner, position, props)
	_ownedPings[owner] = {
        owner = owner,
		instance = instance,
		cleanup = cleanup,
	}

	return PingController.GetPingTag(owner)
end

-- deletes a ping tag from the owned ping list
function PingController.DeletePingTag(owner: Player)
	local data = _ownedPings[owner]
	if data and data.cleanup then
		data.cleanup()
	end
	_ownedPings[owner] = nil
end

function PingController.DeleteAllPingTags()
	for owner, _ in _ownedPings do
		PingController.DeletePingTag(owner)
	end
end

return PingController
