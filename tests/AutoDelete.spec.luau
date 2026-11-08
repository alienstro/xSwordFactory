local H = require("./Harness")
local AutoDelete = require("../src/Shared/AutoDelete")
local describe, it, expect = H.describe, H.it, H.expect

-- A sword with a total rarity of `oneIn`. Wood has 5 damage.
local function sword(props: { [string]: any }?)
	local p = props or {}
	return {
		id = "1",
		material = p.material or "Wood",
		quality = p.quality or "Normal",
		maxDurability = 10,
		durability = 10,
		slots = p.slots or 1,
		enchants = p.enchants or {},
		enhance = 0,
		odds = { material = p.oneIn or 2, quality = 1, slots = 1 },
	}
end

-- Rules with auto delete on. `delete` and `keep` change the empty filters.
local function rules(delete: { [string]: any }?, keep: { [string]: any }?, stopTier: number?)
	local r = AutoDelete.newRules()
	r.deleteOn = true
	r.stopTier = stopTier or 0
	for k, v in delete or {} do
		r.delete[k] = v
	end
	for k, v in keep or {} do
		r.keep[k] = v
	end
	return r
end

describe("AutoDelete", function()
	it("deletes nothing when auto delete is off", function()
		local r = rules({ materials = { "Wood" } })
		r.deleteOn = false
		expect(AutoDelete.shouldDelete(r, sword())).toBe(false)
	end)

	it("deletes nothing when the Delete filter is empty", function()
		expect(AutoDelete.shouldDelete(rules(), sword())).toBe(false)
	end)

	it("deletes a sword that matches a Delete material", function()
		local r = rules({ materials = { "Stone", "Wood" } })
		expect(AutoDelete.shouldDelete(r, sword())).toBe(true)
		expect(AutoDelete.shouldDelete(r, sword({ material = "Iron" }))).toBe(false)
	end)

	it("deletes a sword that matches a Delete tier", function()
		local r = rules({ tiers = { 1 } })
		expect(AutoDelete.shouldDelete(r, sword({ oneIn = 5 }))).toBe(true) -- Common
		expect(AutoDelete.shouldDelete(r, sword({ oneIn = 50 }))).toBe(false) -- Uncommon
	end)

	it("deletes a sword with a Delete quality or enchant", function()
		expect(AutoDelete.shouldDelete(rules({ qualities = { "Worn" } }), sword({ quality = "Worn" }))).toBe(true)
		local fire = { { id = "Fire", level = 1, oneIn = 1 } }
		expect(AutoDelete.shouldDelete(rules({ enchants = { "Fire" } }), sword({ enchants = fire }))).toBe(true)
		expect(AutoDelete.shouldDelete(rules({ enchants = { "Fire" } }), sword())).toBe(false)
	end)

	it("deletes a sword with damage below the Delete damage", function()
		expect(AutoDelete.shouldDelete(rules({ damage = 6 }), sword())).toBe(true) -- 5 < 6
		expect(AutoDelete.shouldDelete(rules({ damage = 5 }), sword())).toBe(false)
	end)

	it("deletes a sword with slots at most the Delete slots", function()
		expect(AutoDelete.shouldDelete(rules({ slots = 1 }), sword({ slots = 1 }))).toBe(true)
		expect(AutoDelete.shouldDelete(rules({ slots = 1 }), sword({ slots = 2 }))).toBe(false)
		expect(AutoDelete.shouldDelete(rules({ slots = 0 }), sword({ slots = 0 }))).toBe(true)
	end)

	it("keeps a sword that matches a Keep enchant even if it matches Delete", function()
		local fire = { { id = "Fire", level = 1, oneIn = 1 } }
		local r = rules({ materials = { "Wood" } }, { enchants = { "Fire" } })
		expect(AutoDelete.shouldDelete(r, sword({ enchants = fire }))).toBe(false)
		expect(AutoDelete.shouldDelete(r, sword())).toBe(true)
	end)

	it("keeps a sword with damage at least the Keep damage", function()
		local r = rules({ materials = { "Wood" } }, { damage = 5 })
		expect(AutoDelete.shouldDelete(r, sword())).toBe(false)
	end)

	it("keeps a sword at or above the Stop at tier", function()
		local r = rules({ tiers = { 1, 2, 3 } }, nil, 2)
		expect(AutoDelete.shouldDelete(r, sword({ oneIn = 50 }))).toBe(false) -- Uncommon = Stop at
		expect(AutoDelete.shouldDelete(r, sword({ oneIn = 5 }))).toBe(true) -- Common
	end)

	it("keeps a sword of 1 in 1,000 or rarer", function()
		local r = rules({ materials = { "Wood" } })
		expect(AutoDelete.shouldDelete(r, sword({ oneIn = 1000 }))).toBe(false)
	end)

	it("reachesStop is false when Stop at is Never", function()
		expect(AutoDelete.reachesStop(rules(), sword({ oneIn = 100000 }))).toBe(false)
		expect(AutoDelete.reachesStop(rules(nil, nil, 3), sword({ oneIn = 100 }))).toBe(true)
		expect(AutoDelete.reachesStop(rules(nil, nil, 3), sword({ oneIn = 99 }))).toBe(false)
	end)

	it("clean drops unknown ids and bad numbers", function()
		local r = AutoDelete.clean({
			stopTier = 9,
			deleteOn = "yes",
			delete = { tiers = { 1, 7, 2.5, "x" }, materials = { "Wood", "Plastic" }, qualities = { "Worn", 3 }, enchants = { "Fire", "Ice" }, slots = 99, damage = -4 },
			keep = { damage = 1 / 0, slots = 2 },
		})
		expect(r.stopTier).toBe(0)
		expect(r.deleteOn).toBe(false)
		expect(r.delete.tiers).toEqual({ 1 })
		expect(r.delete.materials).toEqual({ "Wood" })
		expect(r.delete.qualities).toEqual({ "Worn" })
		expect(r.delete.enchants).toEqual({ "Fire" })
		expect(r.delete.slots).toBe(-1)
		expect(r.delete.damage).toBe(0)
		expect(r.keep.damage).toBe(0)
		expect(r.keep.slots).toBe(2)
	end)

	it("clean limits each list to 40 items", function()
		local many = {}
		for _ = 1, 100 do
			table.insert(many, "Wood")
		end
		expect(#AutoDelete.clean({ delete = { materials = many } }).delete.materials).toBe(40)
	end)

	it("clean of a non-table returns new rules", function()
		expect(AutoDelete.clean(nil)).toEqual(AutoDelete.newRules())
		expect(AutoDelete.clean("bad")).toEqual(AutoDelete.newRules())
		expect(AutoDelete.clean({ delete = "bad" }).delete).toEqual(AutoDelete.newRules().delete)
	end)
end)

return nil
