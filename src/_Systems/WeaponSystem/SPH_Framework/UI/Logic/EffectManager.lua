local RunService = game:GetService("RunService")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Maid = require("@game/ReplicatedStorage/Packages/maid")
local Types = require("../Types")
local EffectManager = {}
EffectManager.__index = EffectManager

type EffectManagerData = {
    maid: Maid.Maid,
    activeHitmarkers: Vide.source<{Types.HitmarkerProps}>,
    suppressionFactor: Vide.source<number>,
}
type EffectManagerInterface = typeof(EffectManager)

export type EffectManager = setmetatable<EffectManagerData, EffectManagerInterface>

function EffectManager.new(): EffectManager
    local self: EffectManagerData = {
        maid = Maid.new(),
        activeHitmarkers = Vide.source({}),
        suppressionFactor = Vide.source(0),
    }
    
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
    end))

    return setmetatable(self, EffectManager)
end

-- creates a new hitmarker
function EffectManager.PushHitmarker(self: EffectManager, props: Types.HitmarkerProps)
    local state = self.activeHitmarkers()
    table.insert(state, props)
    self.activeHitmarkers(state)
end

-- pushes the suppression factor
function EffectManager.PushSuppression(self: EffectManager, factor: number)
    self.suppressionFactor(math.clamp(self.suppressionFactor() + factor, 0, 1))
end

function EffectManager.Destroy(self: EffectManager)
    self.maid:DoCleaning()
end

return EffectManager