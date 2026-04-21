local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ConfigurationTypes = require(ReplicatedStorage.SPH_Framework.Core.ConfigurationTypes)

export type BridgeTool = Tool | { [string]: any }

--- Shared result from EvaluateHit → DealDamage. Optional fields are handler-specific (e.g. Human sets `damage`; DTS stashes rolls on `meta`).
export type HitEvaluation = {
	applies: boolean,
	valid: boolean,
	damage: number?,
	meta: { [string]: any }?,
}

export type HitContext = {
	player: Player,
	tool: BridgeTool,
	equippedTool: Tool,
	wepStats: ConfigurationTypes.WeaponStats,
	raycastResult: RaycastResult,
	bulletCFrame: CFrame,
	hitPart: BasePart,
	humanoid: Humanoid?,
	otherPlayer: Player?,
	allowHumanDamage: boolean,
}

export type CombatHitHandler = {
	EvaluateHit: (HitContext) -> HitEvaluation,
	DealDamage: (HitContext, HitEvaluation) -> boolean?,
}

return {}
