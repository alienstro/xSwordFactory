local H = require("./Harness")
local Sword = require("../src/shared/Sword")
local describe, it, expect = H.describe, H.it, H.expect

local function mithril()
	return {
		id = "1",
		material = "Mithril",
		quality = "Normal",
		maxDurability = 40,
		durability = 40,
		slots = 2,
		enchants = { { id = "Lifesteal", level = 1, oneIn = 40 } },
		enhance = 3,
		odds = { material = 1000, quality = 2, slots = 10 },
	}
end

describe("Sword", function()
	it('name "Mithril Sword +3"', function()
		expect(Sword.name(mithril())).toBe("Mithril Sword +3")
		local s = mithril()
		s.enhance = 0
		expect(Sword.name(s)).toBe("Mithril Sword")
	end)

	it("+10 adds 100 % damage", function()
		local s = mithril()
		s.enhance = 10
		expect(Sword.damage(s)).toBeCloseTo(100)
		s.enhance = 0
		expect(Sword.damage(s)).toBeCloseTo(50)
	end)

	it("rarity is the product of parts", function()
		expect(Sword.rarity(mithril())).toBeCloseTo(1000 * 2 * 10 * 40)
	end)

	it("repair cost 0 at full durability", function()
		local s = mithril()
		expect(Sword.repairCost(s)).toBe(0)
		s.durability = 30
		-- Mithril is material 7: 1 + 0.5 * 6 = 4 gold for each point.
		expect(Sword.repairCost(s)).toBe(40)
	end)

	it("empty slots and enchant level", function()
		local s = mithril()
		expect(Sword.emptySlots(s)).toBe(1)
		expect(Sword.enchantLevel(s, "Lifesteal")).toBe(1)
		expect(Sword.enchantLevel(s, "Fire")).toBe(0)
		expect(Sword.enchantPower("Lifesteal", 2)).toBeCloseTo(0.10)
	end)

	it("salvage gives more gold for a rarer sword", function()
		local common = mithril()
		common.odds = { material = 1.7, quality = 1, slots = 1 }
		common.enchants = {}
		common.enhance = 0
		expect(Sword.salvageValue(mithril())).toBeAtLeast(Sword.salvageValue(common) + 1)
	end)
end)

return nil
