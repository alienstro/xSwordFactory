local H = require("./Harness")
local Actions = require("../src/shared/Actions")
local RateLimit = require("../src/shared/RateLimit")
local Config = require("../src/shared/Config")
local describe, it, expect = H.describe, H.it, H.expect

local ZERO = H.fixedRng({ 0 })

local function setup()
	local data = Actions.newData()
	local session = Actions.newSession()
	return data, session
end

local function forgeOne(data, session)
	local r = Actions.run(data, session, "Forge", {}, ZERO)
	expect(r.ok).toBe(true)
	return data.swords[#data.swords]
end

local function copy(t)
	local out = {}
	for k, v in t do
		out[k] = if type(v) == "table" then copy(v) else v
	end
	return out
end

describe("Actions", function()
	it("forge costs gold and adds a sword", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		expect(data.gold).toBe(Config.StartingGold - Config.ForgeCost)
		expect(#data.swords).toBe(1)
		expect(sword.id).toBe("1")
		expect(data.nextSwordId).toBe(2)
		expect(data.pity).toBe(1)
	end)

	it("too little gold fails and changes nothing", function()
		local data, session = setup()
		data.gold = 3
		local before = copy(data)
		for _, call in { { "Forge", {} }, { "Upgrade", { upgradeId = "Luck" } } } do
			local r = Actions.run(data, session, call[1], call[2], ZERO)
			expect(r.ok).toBe(false)
			expect(r.err).toBe("Not enough gold.")
		end
		expect(data).toEqual(before)
	end)

	it("a full sword list blocks the forge", function()
		local data, session = setup()
		data.gold = 1000000
		for _ = 1, Config.MaxSwords do
			forgeOne(data, session)
		end
		local r = Actions.run(data, session, "Forge", {}, ZERO)
		expect(r.ok).toBe(false)
		expect(#data.swords).toBe(Config.MaxSwords)
	end)

	it("cannot salvage the equipped sword", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		expect(Actions.run(data, session, "Equip", { swordId = sword.id }, ZERO).ok).toBe(true)
		local r = Actions.run(data, session, "Salvage", { swordId = sword.id }, ZERO)
		expect(r.ok).toBe(false)
		expect(#data.swords).toBe(1)
	end)

	it("salvage gives gold and removes the sword", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		local gold = data.gold
		expect(Actions.run(data, session, "Salvage", { swordId = sword.id }, ZERO).ok).toBe(true)
		expect(#data.swords).toBe(0)
		expect(data.gold).toBeAtLeast(gold + 1)
	end)

	it("a broken sword cannot fight", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		Actions.run(data, session, "Equip", { swordId = sword.id }, ZERO)
		sword.durability = 0
		local r = Actions.run(data, session, "StartFight", { monsterIndex = 1 }, ZERO)
		expect(r.ok).toBe(false)
		expect(session.fight).toBe(nil)
	end)

	it("enchant fails with no empty slot", function()
		local data, session = setup()
		local sword = forgeOne(data, session) -- fixed rng 0 gives 0 slots
		expect(sword.slots).toBe(0)
		local gold = data.gold
		local r = Actions.run(data, session, "Enchant", { swordId = sword.id }, ZERO)
		expect(r.ok).toBe(false)
		expect(data.gold).toBe(gold)
	end)

	it("enchant fills an empty slot", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		sword.slots = 2
		local r = Actions.run(data, session, "Enchant", { swordId = sword.id }, ZERO)
		expect(r.ok).toBe(true)
		expect(#sword.enchants).toBe(1)
		expect(sword.enchants[1].id).toBe("Sharpness")
	end)

	it("enhance success and failure", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		sword.enhance = 9
		data.gold = 10000
		local r = Actions.run(data, session, "Enhance", { swordId = sword.id }, H.fixedRng({ 0.5 }))
		expect(r.ok).toBe(true)
		expect(r.success).toBe(false)
		expect(sword.enhance).toBe(9)
		r = Actions.run(data, session, "Enhance", { swordId = sword.id }, H.fixedRng({ 0.1 }))
		expect(r.success).toBe(true)
		expect(sword.enhance).toBe(10)
		r = Actions.run(data, session, "Enhance", { swordId = sword.id }, ZERO)
		expect(r.ok).toBe(false)
	end)

	it("repair restores durability", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		expect(Actions.run(data, session, "Repair", { swordId = sword.id }, ZERO).ok).toBe(false)
		sword.durability = 1
		expect(Actions.run(data, session, "Repair", { swordId = sword.id }, ZERO).ok).toBe(true)
		expect(sword.durability).toBe(sword.maxDurability)
	end)

	it("fight uses 1 durability", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		Actions.run(data, session, "Equip", { swordId = sword.id }, ZERO)
		local before = sword.durability
		expect(Actions.run(data, session, "StartFight", { monsterIndex = 1 }, ZERO).ok).toBe(true)
		expect(sword.durability).toBe(before - 1)
	end)

	it("a locked monster cannot be fought", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		Actions.run(data, session, "Equip", { swordId = sword.id }, ZERO)
		expect(Actions.run(data, session, "StartFight", { monsterIndex = 2 }, ZERO).ok).toBe(false)
		expect(Actions.run(data, session, "StartFight", { monsterIndex = 1.5 }, ZERO).ok).toBe(false)
	end)

	it("win gives gold and unlocks the next monster", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		Actions.run(data, session, "Equip", { swordId = sword.id }, ZERO)
		Actions.run(data, session, "StartFight", { monsterIndex = 1 }, ZERO)
		session.fight.monsterHealth = 1
		local gold = data.gold
		local r = Actions.run(data, session, "FightTurn", { action = "Attack" }, H.fixedRng({ 0.5 }))
		expect(r.outcome).toBe("win")
		expect(data.gold).toBe(gold + Config.Monsters[1].gold)
		expect(data.unlocked).toBe(2)
	end)

	it("a lost fight keeps the sword", function()
		local data, session = setup()
		local sword = forgeOne(data, session)
		Actions.run(data, session, "Equip", { swordId = sword.id }, ZERO)
		Actions.run(data, session, "StartFight", { monsterIndex = 1 }, ZERO)
		session.fight.playerHealth = 1
		local r = Actions.run(data, session, "FightTurn", { action = "Attack" }, H.fixedRng({ 0.5 }))
		expect(r.outcome).toBe("lose")
		expect(#data.swords).toBe(1)
		expect(data.unlocked).toBe(1)
	end)

	it("bad input fails and does not crash", function()
		local data, session = setup()
		for _, call in {
			{ "Nope", {} },
			{ "Equip", { swordId = 5 } },
			{ "Equip", "x" },
			{ "Upgrade", { upgradeId = "Gold" } },
			{ "FightTurn", { action = "Attack" } },
		} do
			local r = Actions.run(data, session, call[1], call[2], ZERO)
			expect(r.ok).toBe(false)
		end
	end)

	it("upgrade raises the level and costs more each time", function()
		local data, session = setup()
		data.gold = 100000
		expect(Actions.run(data, session, "Upgrade", { upgradeId = "Luck" }, ZERO).ok).toBe(true)
		expect(data.upgrades.Luck).toBe(1)
		local gold = data.gold
		Actions.run(data, session, "Upgrade", { upgradeId = "Luck" }, ZERO)
		expect(gold - data.gold).toBe(Config.Upgrades[1].cost(1))
	end)
end)

describe("RateLimit", function()
	it("rate limit blocks a burst", function()
		local bucket = RateLimit.new(8, 15)
		local allowed = 0
		for _ = 1, 30 do
			if RateLimit.allow(bucket, 100) then
				allowed += 1
			end
		end
		expect(allowed).toBe(15)
		expect(RateLimit.allow(bucket, 101)).toBe(true)
	end)
end)

return nil
