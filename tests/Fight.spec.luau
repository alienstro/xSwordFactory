local H = require("./Harness")
local Fight = require("../src/shared/Fight")
local Config = require("../src/shared/Config")
local describe, it, expect = H.describe, H.it, H.expect

local function sword(material: string, enchants)
	return {
		id = "1",
		material = material,
		quality = "Normal",
		maxDurability = 10,
		durability = 10,
		slots = 5,
		enchants = enchants or {},
		enhance = 0,
		odds = { material = 1, quality = 1, slots = 1 },
	}
end

-- 0.5 gives a monster hit of exactly its attack.
local MID = H.fixedRng({ 0.5 })

describe("Fight", function()
	it("attack lowers monster health", function()
		local f = Fight.new(sword("Iron"), 3)
		local r = Fight.turn(f, "Attack", MID)
		expect(f.monsterHealth).toBe(72 - 12)
		expect(f.playerHealth).toBe(100 - 8)
		expect(r.outcome).toBe(nil)
		expect(r.log[1]).toBe("You hit the Goblin for 12 damage.")
	end)

	it("defend halves the next hit", function()
		local f = Fight.new(sword("Iron"), 3)
		Fight.turn(f, "Defend", MID)
		expect(f.monsterHealth).toBe(72)
		expect(f.playerHealth).toBe(100 - 4)
		Fight.turn(f, "Attack", MID)
		expect(f.playerHealth).toBe(100 - 4 - 8)
	end)

	it("special has a 3-turn cooldown", function()
		local f = Fight.new(sword("Wood"), 10)
		Fight.turn(f, "Special", MID)
		expect(f.monsterHealth).toBe(900 - 10)
		local r = Fight.turn(f, "Special", MID)
		expect(r.error).toBeTruthy()
		expect(f.monsterHealth).toBe(900 - 10)
		for _ = 1, 3 do
			Fight.turn(f, "Attack", MID)
		end
		r = Fight.turn(f, "Special", MID)
		expect(r.error).toBe(nil)
		expect(f.monsterHealth).toBe(900 - 10 - 15 - 10)
	end)

	it("flee ends with no reward", function()
		local f = Fight.new(sword("Iron"), 3)
		local r = Fight.turn(f, "Flee", MID)
		expect(r.outcome).toBe("fled")
		expect(f.over).toBe(true)
	end)

	it("Execute kills at low health", function()
		-- Execute I kills below 7 %. Steel hits 18 of 300 Wraith health.
		local f = Fight.new(sword("Steel", { { id = "Execute", level = 1, oneIn = 2500 } }), 7)
		f.monsterHealth = 30
		local r = Fight.turn(f, "Attack", MID)
		expect(f.monsterHealth).toBe(0)
		expect(r.outcome).toBe("win")
	end)

	it("Fire burns after a hit", function()
		local f = Fight.new(sword("Wood", { { id = "Fire", level = 2, oneIn = 8 } }), 10)
		Fight.turn(f, "Attack", MID)
		expect(f.monsterHealth).toBe(900 - 5 - 6)
	end)

	it("fitting sword wins in 5 to 10 turns", function()
		for i, material in Config.Materials do
			for seed = 1, 20 do
				local rng = H.rng(seed * 31 + i)
				local f = Fight.new(sword(material.id), i)
				local turns, outcome = 0, nil
				while not outcome and turns < 50 do
					turns += 1
					outcome = Fight.turn(f, "Attack", rng).outcome
				end
				expect(outcome).toBe("win")
				expect(turns).toBeAtLeast(5)
				expect(turns).toBeAtMost(10)
			end
		end
	end)

	it("a weak sword loses against the boss", function()
		local f = Fight.new(sword("Wood"), 10)
		local outcome = nil
		while not outcome do
			outcome = Fight.turn(f, "Attack", MID).outcome
		end
		expect(outcome).toBe("lose")
	end)
end)

return nil
