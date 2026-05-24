local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Types = {}

export type HitmarkerProps = {
    springPeriod: number,
    springDamping: number,
    image: string,
    position: UDim2,
    size: UDim2,
    transparency: NumberSequence | number,
    scale: NumberSequence | number,
    color: ColorSequence | Color3,
    rotation: NumberSequence | number,
    lifetime: number,
    TimeElapsed: Vide.source<number> | nil,
}

export type EffectViewProps = {
    activeHitmarkers: Vide.source<{HitmarkerProps}>,
    suppressionFactor: Vide.source<number>,
}

return Types