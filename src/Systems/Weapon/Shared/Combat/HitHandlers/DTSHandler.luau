local HitContextTypes = require(script.Parent.Parent.HitContextTypes)

local M = {}

local _atmod = nil
local _useBulletForce = false

function M.Initialize(init)
	_atmod = init.atmod
	_useBulletForce = init.useBulletForce
end

function M.EvaluateHit(context: HitContextTypes.HitContext)
	local wepStats = context.wepStats
	if not _atmod or not wepStats.ATCanDamage then
		return { applies = false, valid = false }
	end

	local hitPart = context.hitPart
	local pen = math.random(wepStats.ATDefaultPen[1], wepStats.ATDefaultPen[2])
	local dmg = math.random(wepStats.ATDefaultDamage[1], wepStats.ATDefaultDamage[2])
	local knockback = (_useBulletForce and Vector3.new(0, 0, -(wepStats.bulletForce or 0))) or nil

	local branch
	if hitPart and hitPart:HasTag("Dragoon_Armor") then
		branch = "vehicle"
	elseif not hitPart:HasTag("Dragoon_Armor") and not hitPart:HasTag("PropSystem_Armor") then
		branch = "misc"
	elseif hitPart:HasTag("PropSystem_Armor") then
		branch = "prop"
	end

	return {
		applies = true,
		valid = true,
		meta = {
			pen = pen,
			dmg = dmg,
			knockback = knockback,
			branch = branch,
		},
	}
end

function M.DealDamage(context: HitContextTypes.HitContext, evaluation: HitContextTypes.HitEvaluation)
	assert(_atmod, "DTS DealDamage called without Antitank")
	local meta = evaluation.meta
	assert(meta, "DTS DealDamage expects evaluation.meta")

	local player = context.player
	local hitPart = context.hitPart

	if meta.branch == "vehicle" then
		_atmod.DamageVehicle(player, hitPart, meta.pen, meta.dmg, meta.knockback, true)
	elseif meta.branch == "misc" then
		_atmod.DamageMisc(player, hitPart, hitPart.Position, nil, meta.pen, meta.dmg, meta.dmg, meta.knockback, true)
	elseif meta.branch == "prop" then
		_atmod.DamageProp(player, hitPart, meta.pen, meta.dmg, meta.knockback, true)
	end
	return nil
end

return M
