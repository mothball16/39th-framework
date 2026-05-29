local Vide = require("@game/ReplicatedStorage/Packages/Vide")
local Types = {}

export type HitmarkerProps = {
    soundType: string,
    smoothingOffset: number,
    image: string,
    size: UDim2,
    transparency: NumberSequence | number,
    scale: NumberSequence | number,
    color: ColorSequence | Color3,
    rotation: NumberSequence | number,
    lifetime: number,
    Position: Vide.source<UDim2>,
    TimeElapsed: Vide.source<number> | nil,
}

export type EffectViewProps = {
    activeHitmarkers: Vide.source<{HitmarkerProps}>,
    suppressionFactor: Vide.source<number>,
    activeDamage: Vide.source<number>,
    panelPosition: Vide.source<Vector2>,
    suppressionLimit: number,
}

export type SuppressionCanvasProps = {
    minSize: UDim2,
    factor: Vide.source<number>,
}

return Types