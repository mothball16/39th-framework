local TableUtil = require("@game/ReplicatedStorage/Packages/table-util")
local Maid = require("@game/ReplicatedStorage/Packages/maid")
local Charm = require("@game/ReplicatedStorage/Packages/Charm")
local useAtom = require("@game/ReplicatedStorage/Packages/vide-charm").useAtom
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Players = game:GetService("Players")

local create = Vide.create
local mount = Vide.mount

local Types = require("@game/ReplicatedStorage/Aware_Framework/Core/Types")
local PingTag = require("./UI/Roots/PingTag")


type PingInstanceProps = Types.PingTagProps & { size: Charm.Atom<UDim2> }

export type CleanupFunction = () -> ()

local PingController = {}
PingController.__index = PingController


type self = {
    _ownedPings: {[Player]: {instance: Instance, cleanup: CleanupFunction}},
    _maid: Maid.Maid,
}

export type PingController = typeof(setmetatable({} :: self, PingController))

function PingController.new(): PingController
    local self = setmetatable({
        _ownedPings = {},
        _maid = Maid.new(),
    }, PingController)

    self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
        self:DeletePingTag(player)
    end))
    
    return self
end


-- builds a ping tag without any state registration
function PingController.CreatePingTag(self: PingController, owner: Instance, position: Vector3, props: PingInstanceProps): (CleanupFunction, Instance)
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

function PingController.GetPingTags(self: PingController): {[Player]: Instance}
    return TableUtil.Map(self._ownedPings, function(value)
        return value and value["instance"] or nil
    end)
end

function PingController.GetPingTag(self: PingController, owner: Player): Instance
    local data = self._ownedPings[owner]
    return data and data["instance"] or nil
end

-- clears, builds and registers a ping tag with the controller
function PingController.RegisterPingTag(self: PingController, owner: Player, position: Vector3, props: PingInstanceProps): Instance
    -- delete any existing ping tag for this owner
    self:DeletePingTag(owner)

    local cleanup, instance = self:CreatePingTag(owner, position, props)
    self._ownedPings[owner] = {
        instance = instance,
        cleanup = cleanup,
    }

    return self:GetPingTag(owner)
end

-- deletes a ping tag from the owned ping list
function PingController.DeletePingTag(self: PingController, owner: Player)
    local data = self._ownedPings[owner]
    if data and data.cleanup then
        data.cleanup()
    end
    self._ownedPings[owner] = nil
end

function PingController.DeleteAllPingTags(self: PingController)
    for owner, _ in self._ownedPings do
        self:DeletePingTag(owner)
    end
end

function PingController.Destroy(self: PingController)
    self:DeleteAllPingTags()
    self._maid:DoCleaning()
end

return PingController