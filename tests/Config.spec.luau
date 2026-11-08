local H = require("./Harness")
local Config = require("../src/Shared/Config")
local describe, it, expect = H.describe, H.it, H.expect

local function restCount(entries): number
	local n = 0
	for _, e in entries do
		if e.oneIn == nil then
			n += 1
		end
	end
	return n
end

describe("Config", function()
	it("each roll table has one rest entry", function()
		expect(restCount(Config.Materials)).toBe(1)
		expect(restCount(Config.Qualities)).toBe(1)
		expect(restCount(Config.SlotCounts)).toBe(1)
		expect(restCount(Config.Enchants)).toBe(1)
		expect(restCount(Config.EnchantLevels)).toBe(1)
	end)

	it("has the spec values", function()
		expect(#Config.Materials).toBe(10)
		expect(Config.Materials[10].name).toBe("Starmetal")
		expect(Config.Materials[10].oneIn).toBe(100000)
		expect(#Config.Enchants).toBe(10)
		expect(#Config.Monsters).toBe(10)
		expect(Config.StartingGold).toBe(200)
		expect(Config.MaxSwords).toBe(50)
		expect(Config.EnhanceChance[10]).toBe(0.2)
	end)
end)

return nil
