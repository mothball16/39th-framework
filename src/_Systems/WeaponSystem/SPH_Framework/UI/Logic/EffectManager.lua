local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Maid = require("@game/ReplicatedStorage/Packages/maid")
local Types = require("../Types")
local Access = require(ReplicatedStorage.SPH_Framework.Access)
local assets = Access.assets
local EffectManager = {}
EffectManager.__index = EffectManager

type self = {
    maid: Maid.Maid,
    activeHitmarkers: Vide.source<{Types.HitmarkerProps}>,
    _suppressionSource: Vide.source<number>,
}

export type EffectManager = setmetatable<self, typeof(EffectManager)>

function EffectManager.new(suppressionSource: Vide.source<number>): EffectManager
    local self = setmetatable({
        maid = Maid.new(),
        activeHitmarkers = Vide.source({}),
        _suppressionSource = suppressionSource,
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
    end))

    return self
end

function EffectManager.PushHitmarker(self: EffectManager, props: Types.HitmarkerProps)
    if Access.assets then
        -- game stuff
        if not Access.config.hitmarkers then
            return
        end
        local soundList = assets.Sounds.Hitmarkers[props.soundType]:GetChildren() :: { Sound }
        local sound = soundList[math.random(#soundList)]
        SoundService:PlayLocalSound(sound)    
    end 

    local state = self.activeHitmarkers()
    table.insert(state, props)
    self.activeHitmarkers(state)
end

function EffectManager.Destroy(self: EffectManager)
    self.maid:DoCleaning()
end

return EffectManager
