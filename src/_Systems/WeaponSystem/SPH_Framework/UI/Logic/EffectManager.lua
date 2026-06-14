local RunService = game:GetService("RunService")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Maid = require("@game/ReplicatedStorage/Packages/maid")
local Types = require("../Types")
local EffectManager = {}
EffectManager.__index = EffectManager

type self = {
    maid: Maid.Maid,
    activeHitmarkers: Vide.source<{
        props: Types.HitmarkerProps,
        anchorPoint: Vector3 | nil
    }>,
    activeDamage: Vide.source<{number}>,

    _suppressionSource: Vide.source<number>,
    _lastDamageUpdate: number,
}

export type EffectManager = setmetatable<self, typeof(EffectManager)>

local DAMAGE_DISPLAY_TIME = 3

function EffectManager.new(suppressionSource: Vide.source<number>, suppressionRecovery: number): EffectManager
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
        for i, hitmarker in state do
            if hitmarker.anchorPoint then
                local screenPoint, onScreen = game.Workspace.CurrentCamera:WorldToViewportPoint(hitmarker.anchorPoint)
	            if onScreen then
                    hitmarker.props.Position(UDim2.fromOffset(screenPoint.X, screenPoint.Y))
                else
                    hitmarker.props.Position(UDim2.fromScale(100, 100))
                end
            end

            hitmarker.props.TimeElapsed(hitmarker.props.TimeElapsed() + dt)
            if hitmarker.props.TimeElapsed() >= hitmarker.props.lifetime then
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

        self._suppressionSource(math.clamp(self._suppressionSource() - dt * suppressionRecovery, 0, 1))
    end))

    return self
end

function EffectManager.PushHitmarker(self: EffectManager, props: Types.HitmarkerProps, anchorPoint: Vector3 | nil, damage: number?)
    local state = table.clone(self.activeHitmarkers())
    table.insert(state, {
        props = props,
        anchorPoint = anchorPoint,
        damage = damage or 0,
    })
    self.activeHitmarkers(state)
end

function EffectManager.PushDamage(self: EffectManager, damage: number)
    self.activeDamage(self.activeDamage() + damage)
    self._lastDamageUpdate = tick()
end

function EffectManager.PushSuppression(self: EffectManager, level: number, factor: number, limit: number | nil)
    local amount = level * factor
    local current = self._suppressionSource()
    -- this prevents a suppression limit from lowering the suppression level
    local cap = if limit == nil then 1 else limit
    local maxSuppression = math.max(cap, current)

	self._suppressionSource(math.clamp(current + amount, 0, maxSuppression))
end

function EffectManager.Destroy(self: EffectManager)
    self.maid:DoCleaning()
end

return EffectManager
