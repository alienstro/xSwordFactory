local H = require("./Harness")
local SwordFilter = require("../src/Shared/SwordFilter")
local describe, it, expect = H.describe, H.it, H.expect

-- A sword with a total rarity of `oneIn`. Wood has 5 damage, Iron has 12 damage.
local function sword(id: string, props: { [string]: any }?)
	local p = props or {}
	return {
		id = id,
		material = p.material or "Wood",
		quality = p.quality or "Normal",
		maxDurability = 10,
		durability = 10,
		slots = p.slots or 1,
		enchants = p.enchants or {},
		enhance = 0,
		favorite = p.favorite,
		odds = { material = p.oneIn or 2, quality = 1, slots = 1 },
	}
end

local function ids(list: { any }): { string }
	local out = {}
	for _, s in list do
		table.insert(out, s.id)
	end
	return out
end

-- A filter with these fields changed.
local function filter(props: { [string]: any }?)
	local f = SwordFilter.new()
	for k, v in props or {} do
		f[k] = v
	end
	return f
end

describe("SwordFilter", function()
	it("matches each sword when the filter is empty", function()
		expect(SwordFilter.matches(filter(), sword("1"))).toBe(true)
		expect(SwordFilter.activeCount(filter())).toBe(0)
	end)

	it("matches a sword that has one of the selected values in a group", function()
		local f = filter({ materials = { "Stone", "Iron" } })
		expect(SwordFilter.matches(f, sword("1", { material = "Iron" }))).toBe(true)
		expect(SwordFilter.matches(f, sword("2", { material = "Wood" }))).toBe(false)
	end)

	it("needs a match in each active group", function()
		local f = filter({ materials = { "Iron" }, qualities = { "Sturdy" } })
		expect(SwordFilter.matches(f, sword("1", { material = "Iron", quality = "Sturdy" }))).toBe(true)
		expect(SwordFilter.matches(f, sword("2", { material = "Iron", quality = "Normal" }))).toBe(false)
		expect(SwordFilter.activeCount(f)).toBe(2)
	end)

	it("filters by rarity tier", function()
		-- 1 in 2 is Common (tier 1). 1 in 1,000 is Epic (tier 4).
		local f = filter({ tiers = { 4 } })
		expect(SwordFilter.matches(f, sword("1", { oneIn = 1000 }))).toBe(true)
		expect(SwordFilter.matches(f, sword("2", { oneIn = 2 }))).toBe(false)
	end)

	it("filters by enchantment", function()
		local f = filter({ enchants = { "Fire" } })
		expect(SwordFilter.matches(f, sword("1", { enchants = { { id = "Fire", level = 1, oneIn = 8 } } }))).toBe(true)
		expect(SwordFilter.matches(f, sword("2"))).toBe(false)
	end)

	it("filters by minimum damage and minimum slots", function()
		local f = filter({ minDamage = 10 })
		expect(SwordFilter.matches(f, sword("1", { material = "Iron" }))).toBe(true)
		expect(SwordFilter.matches(f, sword("2", { material = "Wood" }))).toBe(false)
		local g = filter({ minSlots = 2 })
		expect(SwordFilter.matches(g, sword("3", { slots = 2 }))).toBe(true)
		expect(SwordFilter.matches(g, sword("4", { slots = 1 }))).toBe(false)
	end)

	it("shows only favorites when favoritesOnly is on", function()
		local f = filter({ favoritesOnly = true })
		expect(SwordFilter.matches(f, sword("1", { favorite = true }))).toBe(true)
		expect(SwordFilter.matches(f, sword("2"))).toBe(false)
	end)

	it("puts the equipped sword first, then sorts by rarity", function()
		local swords = { sword("a", { oneIn = 2 }), sword("b", { oneIn = 100 }), sword("c", { oneIn = 10 }) }
		expect(ids(SwordFilter.apply(swords, filter(), "rarity", "a"))).toEqual({ "a", "b", "c" })
	end)

	it("sorts by damage", function()
		local swords = { sword("a", { material = "Wood" }), sword("b", { material = "Iron" }), sword("c", { material = "Stone" }) }
		expect(ids(SwordFilter.apply(swords, filter(), "damage", nil))).toEqual({ "b", "c", "a" })
	end)

	it("sorts by newest, and keeps a newer sword first when two values are equal", function()
		local swords = { sword("a"), sword("b"), sword("c") }
		expect(ids(SwordFilter.apply(swords, filter(), "newest", nil))).toEqual({ "c", "b", "a" })
		expect(ids(SwordFilter.apply(swords, filter(), "rarity", nil))).toEqual({ "c", "b", "a" })
	end)

	it("hides each sword that does not match, the equipped sword too", function()
		local swords = { sword("a", { material = "Wood" }), sword("b", { material = "Iron" }) }
		expect(ids(SwordFilter.apply(swords, filter({ materials = { "Iron" } }), "rarity", "a"))).toEqual({ "b" })
	end)
end)
