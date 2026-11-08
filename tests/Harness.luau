--!strict
-- A small test harness for Lune. It gives describe, it, and expect.

local Harness = {}

local passed = 0
local failed = 0
local prefix: { string } = {}

local function show(value: any): string
	if type(value) == "table" then
		local parts = {}
		for k, v in value do
			table.insert(parts, `{tostring(k)}={show(v)}`)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

function Harness.describe(name: string, fn: () -> ())
	table.insert(prefix, name)
	fn()
	table.remove(prefix)
end

function Harness.it(name: string, fn: () -> ())
	local full = table.concat(prefix, " > ") .. " > " .. name
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print(`FAIL {full}\n     {tostring(err)}`)
	end
end

function Harness.expect(actual: any)
	local e = {}
	function e.toBe(expected: any)
		if actual ~= expected then
			error(`expected {show(expected)}, got {show(actual)}`, 2)
		end
	end
	function e.toEqual(expected: any)
		if not deepEqual(actual, expected) then
			error(`expected {show(expected)}, got {show(actual)}`, 2)
		end
	end
	function e.toBeCloseTo(expected: number, eps: number?)
		if math.abs(actual - expected) > (eps or 1e-6) then
			error(`expected about {expected}, got {show(actual)}`, 2)
		end
	end
	function e.toBeTruthy()
		if not actual then
			error(`expected a truthy value, got {show(actual)}`, 2)
		end
	end
	function e.toBeFalsy()
		if actual then
			error(`expected a falsy value, got {show(actual)}`, 2)
		end
	end
	function e.toBeAtLeast(n: number)
		if actual < n then
			error(`expected at least {n}, got {show(actual)}`, 2)
		end
	end
	function e.toBeAtMost(n: number)
		if actual > n then
			error(`expected at most {n}, got {show(actual)}`, 2)
		end
	end
	return e
end

-- A seeded random source with the same NextNumber method as Roblox Random.
function Harness.rng(seed: number)
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return {
		NextNumber = function(_self)
			state = (state * 16807) % 2147483647
			return (state - 1) / 2147483646
		end,
	}
end

-- A random source that returns the given values in order, then repeats the last one.
function Harness.fixedRng(values: { number })
	local i = 0
	return {
		NextNumber = function(_self)
			i = math.min(i + 1, #values)
			return values[i]
		end,
	}
end

function Harness.summary(): boolean
	print(`{passed} passed, {failed} failed`)
	return failed == 0
end

return Harness
