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


export type CleanupFunction = () -> ()

local PingTagRenderer = {}


-- builds a ping tag without any state registration
function PingTagRenderer.CreatePingTag(owner: Instance, position: Vector3, props: Types.PingTagProps): (CleanupFunction, BasePart)
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
			Size = useAtom(Charm.atom(UDim2.fromOffset(40, 40))), -- TEMP
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


return PingTagRenderer
