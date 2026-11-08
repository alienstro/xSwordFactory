local H = require("./Harness")
local Odds = require("../src/shared/Odds")
local describe, it, expect = H.describe, H.it, H.expect

local entries = {
	{ id = "A" },
	{ id = "B", oneIn = 4 },
	{ id = "C", oneIn = 10 },
}

local function sum(tbl): number
	local s = 0
	for _, row in tbl do
		s += row.p
	end
	return s
end

describe("Odds", function()
	it("build sums to 1", function()
		local tbl = Odds.build(entries, 1, 0.1)
		expect(sum(tbl)).toBeCloseTo(1)
		expect(tbl[1].p).toBeCloseTo(0.65)
		expect(tbl[2].p).toBeCloseTo(0.25)
	end)

	it("mult raises rare entries", function()
		local tbl = Odds.build(entries, 2, 0.1)
		expect(tbl[2].p).toBeCloseTo(0.5)
		expect(tbl[3].p).toBeCloseTo(0.2)
		expect(tbl[1].p).toBeCloseTo(0.3)
	end)

	it("rest never below minRest", function()
		local tbl = Odds.build(entries, 10, 0.1)
		expect(tbl[1].p).toBeCloseTo(0.1)
		expect(sum(tbl)).toBeCloseTo(1)
		-- The rare entries keep their ratio.
		expect(tbl[2].p / tbl[3].p).toBeCloseTo(2.5)
	end)

	it("no rest entry normalizes", function()
		local tbl = Odds.build({ entries[2], entries[3] }, 1, 0.1)
		expect(sum(tbl)).toBeCloseTo(1)
		expect(tbl[1].p / tbl[2].p).toBeCloseTo(2.5)
	end)

	it("roll picks by p", function()
		local tbl = Odds.build(entries, 1, 0.1)
		expect(Odds.roll(tbl, H.fixedRng({ 0.1 })).id).toBe("A")
		expect(Odds.roll(tbl, H.fixedRng({ 0.7 })).id).toBe("B")
		local entry, p = Odds.roll(tbl, H.fixedRng({ 0.95 }))
		expect(entry.id).toBe("C")
		expect(p).toBeCloseTo(0.1)
	end)

	it('format "1 in 2,500,000"', function()
		expect(Odds.format(2500000)).toBe("1 in 2,500,000")
		expect(Odds.format(1234567)).toBe("1 in 1,230,000")
		expect(Odds.format(40)).toBe("1 in 40")
		expect(Odds.format(1.68)).toBe("1 in 1.7")
		expect(Odds.format(2)).toBe("1 in 2")
	end)

	it("tier of 1000 is 4", function()
		expect(Odds.tier(1.5)).toBe(1)
		expect(Odds.tier(25)).toBe(2)
		expect(Odds.tier(1000)).toBe(4)
		expect(Odds.tier(100000)).toBe(6)
	end)
end)

return nil
