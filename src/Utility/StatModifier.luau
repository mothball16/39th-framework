--!strict
--@mothball16

local StatModifier = {}
StatModifier.__index = StatModifier

type self<T> = {
	_base: T,
	_applied: { [string]: any },
	_add: { [string]: any },
	_multiply: { [string]: any },
	_override: { [string]: any },
	_dirty: boolean,
}
export type StatModifier<T> = typeof(setmetatable({} :: self<T>, StatModifier))

function StatModifier.new<T>(base: T): StatModifier<T>
	return (
		setmetatable(
			{
				_base = base,
				_applied = {},
				_add = {},
				_multiply = {},
				_override = {},
				_dirty = true,
			} :: self<T>,
			StatModifier
		)
	)
end

local function setMod(orig: any, mod: any): any
	if not orig then
		return mod
	end

	local origType = typeof(orig)
	if origType == "number" then
		return ((orig :: number) + mod)
	elseif origType == "table" then
		for k, v in pairs(orig) do
			orig[k] = setMod(v, mod)
		end
		return orig
	else
		warn(`unsupported type {origType}`)
		return orig
	end
end

local function applyMod(value, add: any, multiply: any)
	local valueType = typeof(value)
	if valueType == "number" then
		return ((value :: number) + add) * (1 + multiply)
	elseif valueType == "table" then
		for k: any, v: any in pairs(value :: { [string]: any }) do
			-- TODO: refactor this, this is a mess lol
			local addMod = typeof(add) == "number" and add or (add :: { number })[k]
			local multiplyMod = typeof(multiply) == "number" and multiply or (multiply :: { number })[k]
			value[k] = applyMod(v, addMod, multiplyMod)
		end
		return value
	else
		return value
	end
end

local function modifyTable(tbl: { [string]: any }, mod: { [string]: any })
	for key, value in pairs(mod) do
		tbl[key] = setMod(tbl[key], value)
	end
end

function StatModifier.Add<T>(self: StatModifier<T>, mod: T): StatModifier<T>
	modifyTable(self._add, mod)
	self._dirty = true
	return self
end

function StatModifier.Multiply<T>(self: StatModifier<T>, mod: T): StatModifier<T>
	modifyTable(self._multiply, mod)
	self._dirty = true
	return self
end

function StatModifier.Override<T>(self: StatModifier<T>, mod: T): StatModifier<T>
	for key, value in mod :: any do
		self._override[key] = value
	end
	self._dirty = true
	return self
end

function StatModifier.GetStats<T>(self: StatModifier<T>): { [string]: number }
	if self._dirty then
		StatModifier.Apply(self)
	end
	return self._applied
end

function StatModifier.GetKeyModifiers<T>(
	self: StatModifier<T>,
	key: string
): {
	add: number?,
	multiply: number?,
	override: number?,
}
	return {
		add = self._add[key],
		multiply = self._multiply[key],
		override = self._override[key],
	}
end

-- return the base value of the StatModifier instance. DANGEROUS
function StatModifier.GetRaw<T>(self: StatModifier<T>): T
	return self._base
end

-- manually update stat modifiers (not recommended)
function StatModifier.Apply<T>(self: StatModifier<T>)
	for k, v in pairs(self._base :: any) do
		local add = self._add[k] or 0
		local multiply = self._multiply[k] or 0
		local override = self._override[k] or nil
		local startValue = override or v

		self._applied[k] = applyMod(startValue, add, multiply)
	end
	self._dirty = false
end

return StatModifier
