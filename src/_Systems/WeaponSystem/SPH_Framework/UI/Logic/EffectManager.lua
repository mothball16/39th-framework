local RunService = game:GetService("RunService")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Maid = require("@game/ReplicatedStorage/Packages/maid")
local Types = require("../Types")
local EffectManager = {}
EffectManager.__index = EffectManager

type self = {
    maid: Maid.Maid,
    activeHitmarkers: Vide.source<{Types.HitmarkerProps}>,
    activeDamage: Vide.source<{number}>,

    _suppressionSource: Vide.source<number>,
    _lastDamageUpdate: number,
}

export type EffectManager = setmetatable<self, typeof(EffectManager)>

local DAMAGE_DISPLAY_TIME = 3

function EffectManager.new(suppressionSource: Vide.source<number>): EffectManager
    local self = setmetatable({
        maid = Maid.new(),
        activeHitmarkers = Vide.source({}),
        activeDamage = Vide.source(0),
        _suppressionSource = suppressionSource,
        _lastDamageUpdate = tick(),
    } :: self, EffectManager)
    
    -- hitmarker lifetime upd
    self.maid:GiveTask(RunService.RenderStepped:Connect(function(dt)
        local state = self.activeHitmarkers()
        local indexesDirty = false
        for i, v in state do
            v.TimeElapsed(v.TimeElapsed() + dt)
            if v.TimeElapsed() >= v.lifetime then
                state[i] = nil
                indexesDirty = true
            end
        end

        if indexesDirty then
            self.activeHitmarkers(state)
        end

        if tick() - self._lastDamageUpdate > DAMAGE_DISPLAY_TIME then
            self.activeDamage(0)
        end
    end))

    return self
end

function EffectManager.PushHitmarker(self: EffectManager, props: Types.HitmarkerProps)
    local state = self.activeHitmarkers()
    table.insert(state, props)
    self.activeHitmarkers(state)
end

function EffectManager.PushDamage(self: EffectManager, damage: number)
    self.activeDamage(self.activeDamage() + damage)
    self._lastDamageUpdate = tick()
end

function EffectManager.Destroy(self: EffectManager)
    self.maid:DoCleaning()
end

return EffectManager
