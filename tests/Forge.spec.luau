local H = require("./Harness")
local Forge = require("../src/shared/Forge")
local Config = require("../src/shared/Config")
local describe, it, expect = H.describe, H.it, H.expect

local NO_UPGRADES = { Luck = 0, Slots = 0, Durability = 0 }

local function allEnchantsBut(keep: string?)
	local list = {}
	for _, def in Config.Enchants do
		if def.id ~= keep then
			table.insert(list, { id = def.id, level = 1, oneIn = 2 })
		end
	end
	return list
end

describe("Forge", function()
	it("pity forces Steel or better at 60", function()
		local sword, pity = Forge.roll(NO_UPGRADES, Config.PityLimit - 1, H.fixedRng({ 0 }), "1")
		expect(sword.material).toBe("Steel")
		expect(pity).toBe(0)
	end)

	it("pity counts up on a common material", function()
		local sword, pity = Forge.roll(NO_UPGRADES, 10, H.fixedRng({ 0 }), "1")
		expect(sword.material).toBe("Wood")
		expect(pity).toBe(11)
	end)

	it("pity resets on a rare material", function()
		local sword, pity = Forge.roll(NO_UPGRADES, 10, H.fixedRng({ 0.999999, 0 }), "1")
		expect(sword.material).toBe("Starmetal")
		expect(pity).toBe(0)
	end)

	it("enchant roll excludes owned enchants", function()
		local sword = { enchants = allEnchantsBut("Execute"), slots = 5 }
		for _, r in { 0, 0.5, 0.999 } do
			local e = Forge.rollEnchant(NO_UPGRADES, sword, H.fixedRng({ r }))
			expect(e and e.id).toBe("Execute")
		end
	end)

	it("all excluded returns nil", function()
		local sword = { enchants = allEnchantsBut(nil), slots = 5 }
		expect(Forge.rollEnchant(NO_UPGRADES, sword, H.fixedRng({ 0 }))).toBe(nil)
	end)

	it("slots 0..5 and no enchant two times", function()
		local rng = H.rng(42)
		local upgrades = { Luck = 10, Slots = 10, Durability = 10 }
		for i = 1, 3000 do
			local sword = Forge.roll(upgrades, 0, rng, tostring(i))
			expect(sword.slots).toBeAtLeast(0)
			expect(sword.slots).toBeAtMost(5)
			expect(#sword.enchants).toBeAtMost(sword.slots)
			expect(sword.durability).toBe(sword.maxDurability)
			local seen = {}
			for _, e in sword.enchants do
				expect(seen[e.id]).toBe(nil)
				seen[e.id] = true
			end
		end
	end)

	it("the sword stores the odds of each roll", function()
		local sword = Forge.roll(NO_UPGRADES, 0, H.fixedRng({ 0 }), "7")
		expect(sword.id).toBe("7")
		expect(sword.quality).toBe("Worn")
		expect(sword.slots).toBe(0)
		local restP = 1 - (1 / 4 + 1 / 10 + 1 / 25 + 1 / 100 + 1 / 250 + 1 / 1000 + 1 / 2500 + 1 / 10000 + 1 / 100000)
		expect(sword.odds.material).toBeCloseTo(1 / restP)
		expect(sword.maxDurability).toBe(8) -- Wood 10 × Worn 0.8
	end)

	it("luck makes the rare materials more likely", function()
		local base = Forge.tables(NO_UPGRADES)
		local lucky = Forge.tables({ Luck = 5, Slots = 0, Durability = 0 })
		expect(lucky.material[10].p).toBeAtLeast(base.material[10].p * 1.5)
	end)
end)

return nil
