--!strict
-- The auto forge rules: the Stop at tier and the auto delete filters.
-- The server checks each new sword from a forge with these rules.
-- Pure: no Roblox services. The rules come from the client, so clean() checks each value.

local Config = require("./Config")
local Odds = require("./Odds")
local Sword = require("./Sword")

-- A filter matches a sword when one of its parts matches.
-- slots = -1 and damage = 0 mean "not used".
-- In the Delete filter, slots means "at most N" and damage means "below N".
-- In the Keep filter, slots means "at least N" and damage means "at least N".
export type Filter = {
	tiers: { number },
	materials: { string },
	qualities: { string },
	enchants: { string },
	slots: number,
	damage: number,
}

-- stopTier = 0 means "Never". Tiers are 1 (Common) to 6 (Mythic), from Odds.tier.
export type Rules = { stopTier: number, deleteOn: boolean, delete: Filter, keep: Filter }

type Mode = "delete" | "keep"

local AutoDelete = {}

AutoDelete.MaxItems = 40 -- the most items that clean() keeps in one list
AutoDelete.MaxTier = 6
AutoDelete.MaxDamage = 10000
local MAX_READ = 200 -- clean() reads no more items than this from one list

local function idSet(defs: { { id: string } }): { [string]: boolean }
	local set = {}
	for _, def in defs do
		set[def.id] = true
	end
	return set
end

local MATERIALS = idSet(Config.Materials)
local QUALITIES = idSet(Config.Qualities)
local ENCHANTS = idSet(Config.Enchants)
local MAX_SLOTS = 0
for _, def in Config.SlotCounts do
	MAX_SLOTS = math.max(MAX_SLOTS, def.count)
end
AutoDelete.MaxSlots = MAX_SLOTS

local function newFilter(): Filter
	return { tiers = {}, materials = {}, qualities = {}, enchants = {}, slots = -1, damage = 0 }
end

function AutoDelete.newRules(): Rules
	return { stopTier = 0, deleteOn = false, delete = newFilter(), keep = newFilter() }
end

-- True for a whole number from lo to hi. False for NaN, infinity, and other types.
local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v % 1 == 0 and v >= lo and v <= hi
end

local function cleanList(input: any, ok: (any) -> boolean): { any }
	local out = {}
	if type(input) ~= "table" then
		return out
	end
	for i, v in ipairs(input) do
		if i > MAX_READ or #out >= AutoDelete.MaxItems then
			break
		end
		if ok(v) then
			table.insert(out, v)
		end
	end
	return out
end

local function cleanFilter(input: any, mode: Mode): Filter
	if type(input) ~= "table" then
		return newFilter()
	end
	local minSlots = if mode == "delete" then 0 else 1
	return {
		tiers = cleanList(input.tiers, function(v)
			return isInt(v, 1, AutoDelete.MaxTier)
		end),
		materials = cleanList(input.materials, function(v)
			return type(v) == "string" and MATERIALS[v] == true
		end),
		qualities = cleanList(input.qualities, function(v)
			return type(v) == "string" and QUALITIES[v] == true
		end),
		enchants = cleanList(input.enchants, function(v)
			return type(v) == "string" and ENCHANTS[v] == true
		end),
		slots = if isInt(input.slots, minSlots, MAX_SLOTS) then input.slots else -1,
		damage = if isInt(input.damage, 1, AutoDelete.MaxDamage) then input.damage else 0,
	}
end

-- Returns rules that hold only known ids and numbers in range. It never errors.
function AutoDelete.clean(input: any): Rules
	if type(input) ~= "table" then
		return AutoDelete.newRules()
	end
	return {
		stopTier = if isInt(input.stopTier, 0, AutoDelete.MaxTier) then input.stopTier else 0,
		deleteOn = input.deleteOn == true,
		delete = cleanFilter(input.delete, "delete"),
		keep = cleanFilter(input.keep, "keep"),
	}
end

local function has(list: { any }, value: any): boolean
	return table.find(list, value) ~= nil
end

local function matches(filter: Filter, s: Sword.Sword, mode: Mode): boolean
	if has(filter.tiers, Odds.tier(Sword.rarity(s))) then
		return true
	end
	if has(filter.materials, s.material) or has(filter.qualities, s.quality) then
		return true
	end
	for _, e in s.enchants do
		if has(filter.enchants, e.id) then
			return true
		end
	end
	if filter.slots >= 0 then
		if (mode == "delete" and s.slots <= filter.slots) or (mode == "keep" and s.slots >= filter.slots) then
			return true
		end
	end
	if filter.damage > 0 then
		local damage = Sword.damage(s)
		if (mode == "delete" and damage < filter.damage) or (mode == "keep" and damage >= filter.damage) then
			return true
		end
	end
	return false
end

-- True when auto forge must stop for this sword: it reaches the Stop at tier.
function AutoDelete.reachesStop(rules: Rules, s: Sword.Sword): boolean
	return rules.stopTier > 0 and Odds.tier(Sword.rarity(s)) >= rules.stopTier
end

-- True when the server must auto delete this new sword.
-- Keep always wins. A sword that auto forge stops for, or a reveal roll, is never deleted.
function AutoDelete.shouldDelete(rules: Rules, s: Sword.Sword): boolean
	if not rules.deleteOn then
		return false
	end
	if Sword.rarity(s) >= Config.RareFlashOneIn or AutoDelete.reachesStop(rules, s) then
		return false
	end
	return matches(rules.delete, s, "delete") and not matches(rules.keep, s, "keep")
end

return AutoDelete
