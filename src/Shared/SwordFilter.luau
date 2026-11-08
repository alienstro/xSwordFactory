--!strict
-- The filter and the sort of the Swords tab. Only the client uses it: it changes the view, not the data.
-- Pure: no Roblox services.
--
-- A filter has groups. In one group, a sword must have one of the selected values (OR).
-- A sword must match each active group (AND). An empty group is not active.

local Odds = require("./Odds")
local Sword = require("./Sword")

-- minDamage = 0 and minSlots = 0 mean "not used".
export type Filter = {
	tiers: { number },
	materials: { string },
	qualities: { string },
	enchants: { string },
	minDamage: number,
	minSlots: number,
	favoritesOnly: boolean,
}

export type Sort = "rarity" | "damage" | "newest"

local SwordFilter = {}

SwordFilter.Sorts = { "rarity", "damage", "newest" } :: { Sort }
SwordFilter.SortNames = { rarity = "Rarity", damage = "Damage", newest = "Newest" }

function SwordFilter.new(): Filter
	return { tiers = {}, materials = {}, qualities = {}, enchants = {}, minDamage = 0, minSlots = 0, favoritesOnly = false }
end

-- The number of active groups. The UI shows it on the Filter button.
function SwordFilter.activeCount(f: Filter): number
	local count = 0
	for _, list in { f.tiers, f.materials, f.qualities, f.enchants } do
		if #list > 0 then
			count += 1
		end
	end
	if f.minDamage > 0 then
		count += 1
	end
	if f.minSlots > 0 then
		count += 1
	end
	if f.favoritesOnly then
		count += 1
	end
	return count
end

local function inGroup(list: { any }, value: any): boolean
	return #list == 0 or table.find(list, value) ~= nil
end

local function hasEnchant(list: { string }, s: Sword.Sword): boolean
	if #list == 0 then
		return true
	end
	for _, e in s.enchants do
		if table.find(list, e.id) then
			return true
		end
	end
	return false
end

function SwordFilter.matches(f: Filter, s: Sword.Sword): boolean
	return inGroup(f.tiers, Odds.tier(Sword.rarity(s)))
		and inGroup(f.materials, s.material)
		and inGroup(f.qualities, s.quality)
		and hasEnchant(f.enchants, s)
		and (f.minDamage <= 0 or Sword.damage(s) >= f.minDamage)
		and (f.minSlots <= 0 or s.slots >= f.minSlots)
		and (not f.favoritesOnly or s.favorite == true)
end

-- The swords that match, in view order: the equipped sword first, then by the sort, highest first.
-- The list order of `swords` is the forge order, so a higher index is a newer sword.
-- Equal values keep the newer sword first, so the order does not jump between renders.
function SwordFilter.apply(swords: { Sword.Sword }, f: Filter, sort: Sort, equipped: string?): { Sword.Sword }
	local rows = {}
	for i, s in swords do
		if SwordFilter.matches(f, s) then
			local value = if sort == "damage" then Sword.damage(s) elseif sort == "rarity" then Sword.rarity(s) else i
			table.insert(rows, { sword = s, index = i, value = value })
		end
	end
	table.sort(rows, function(a, b)
		local aEquipped, bEquipped = a.sword.id == equipped, b.sword.id == equipped
		if aEquipped ~= bEquipped then
			return aEquipped
		end
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.index > b.index
	end)
	local out = {}
	for _, row in rows do
		table.insert(out, row.sword)
	end
	return out
end

return SwordFilter
