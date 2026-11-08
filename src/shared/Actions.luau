--!strict
-- The rules of each button. The server runs them on the saved data.
-- Pure: no Roblox services. Each action checks its input, because the
-- client can send anything.

local Config = require("./Config")
local Odds = require("./Odds")
local Sword = require("./Sword")
local Forge = require("./Forge")
local Fight = require("./Fight")

export type Data = {
	gold: number,
	swords: { Sword.Sword },
	nextSwordId: number,
	equipped: string?,
	upgrades: Forge.Upgrades,
	pity: number,
	unlocked: number,
	guideDone: boolean,
}
export type Session = { fight: Fight.State? }
export type Result = { ok: boolean, err: string?, [string]: any }

local Actions = {}

function Actions.newData(): Data
	return {
		gold = Config.StartingGold,
		swords = {},
		nextSwordId = 1,
		equipped = nil,
		upgrades = { Luck = 0, Slots = 0, Durability = 0 },
		pity = 0,
		unlocked = 1,
		guideDone = false,
	}
end

function Actions.newSession(): Session
	return { fight = nil }
end

local function fail(err: string): Result
	return { ok = false, err = err }
end

local NOT_ENOUGH_GOLD = "Not enough gold."

local function inFight(session: Session): boolean
	return session.fight ~= nil and not session.fight.over
end

local function findSword(data: Data, args: any): (Sword.Sword?, number?)
	local id = args.swordId
	if type(id) ~= "string" then
		return nil, nil
	end
	for i, s in data.swords do
		if s.id == id then
			return s, i
		end
	end
	return nil, nil
end

local function equippedSword(data: Data): Sword.Sword?
	if not data.equipped then
		return nil
	end
	return (findSword(data, { swordId = data.equipped }))
end

local handlers: { [string]: (Data, Session, any, Odds.Rng) -> Result } = {}

function handlers.Forge(data, _session, _args, rng)
	if #data.swords >= Config.MaxSwords then
		return fail("Your sword list is full. Salvage a sword first.")
	end
	if data.gold < Config.ForgeCost then
		return fail(NOT_ENOUGH_GOLD)
	end
	local sword, pity = Forge.roll(data.upgrades, data.pity, rng, tostring(data.nextSwordId))
	data.gold -= Config.ForgeCost
	data.nextSwordId += 1
	data.pity = pity
	table.insert(data.swords, sword)
	return { ok = true, sword = sword }
end

function handlers.Equip(data, session, args, _rng)
	local sword = findSword(data, args)
	if not sword then
		return fail("You do not have this sword.")
	end
	if inFight(session) then
		return fail("You cannot change swords during a fight.")
	end
	data.equipped = sword.id
	return { ok = true }
end

function handlers.Enhance(data, _session, args, rng)
	local sword = findSword(data, args)
	if not sword then
		return fail("You do not have this sword.")
	end
	if sword.enhance >= Config.MaxEnhance then
		return fail("The sword is at the maximum level.")
	end
	local to = sword.enhance + 1
	local cost = Sword.enhanceCost(to)
	if data.gold < cost then
		return fail(NOT_ENOUGH_GOLD)
	end
	data.gold -= cost
	local success = rng:NextNumber() < Config.EnhanceChance[to]
	if success then
		sword.enhance = to
	end
	return { ok = true, success = success }
end

function handlers.Enchant(data, _session, args, rng)
	local sword = findSword(data, args)
	if not sword then
		return fail("You do not have this sword.")
	end
	if Sword.emptySlots(sword) <= 0 then
		return fail("The sword has no empty slot.")
	end
	if #Forge.enchantTable(data.upgrades, Forge.owned(sword)) == 0 then
		return fail("No enchantment is left for this sword.")
	end
	local cost = Sword.enchantCost(sword)
	if data.gold < cost then
		return fail(NOT_ENOUGH_GOLD)
	end
	local enchant = Forge.rollEnchant(data.upgrades, sword, rng) :: Sword.Enchant
	data.gold -= cost
	table.insert(sword.enchants, enchant)
	return { ok = true, enchant = enchant }
end

function handlers.Repair(data, _session, args, _rng)
	local sword = findSword(data, args)
	if not sword then
		return fail("You do not have this sword.")
	end
	local cost = Sword.repairCost(sword)
	if cost <= 0 then
		return fail("The sword is at full durability.")
	end
	if data.gold < cost then
		return fail(NOT_ENOUGH_GOLD)
	end
	data.gold -= cost
	sword.durability = sword.maxDurability
	return { ok = true }
end

function handlers.Salvage(data, _session, args, _rng)
	local sword, index = findSword(data, args)
	if not sword or not index then
		return fail("You do not have this sword.")
	end
	if data.equipped == sword.id then
		return fail("You cannot salvage the equipped sword.")
	end
	if sword.favorite then
		return fail("Remove the favorite star first.")
	end
	local value = Sword.salvageValue(sword)
	data.gold += value
	table.remove(data.swords, index)
	return { ok = true, gold = value }
end

-- Salvages each sword that is not a favorite and not equipped.
function handlers.SalvageAll(data, _session, _args, _rng)
	local kept = {}
	local count, gold = 0, 0
	for _, s in data.swords do
		if s.favorite or s.id == data.equipped then
			table.insert(kept, s)
		else
			count += 1
			gold += Sword.salvageValue(s)
		end
	end
	if count == 0 then
		return fail("No sword to salvage. Favorites and the equipped sword stay.")
	end
	data.swords = kept
	data.gold += gold
	return { ok = true, count = count, gold = gold }
end

function handlers.Favorite(data, _session, args, _rng)
	local sword = findSword(data, args)
	if not sword then
		return fail("You do not have this sword.")
	end
	sword.favorite = if sword.favorite then nil else true
	return { ok = true, favorite = sword.favorite == true }
end

function handlers.Upgrade(data, _session, args, _rng)
	local def
	for _, d in Config.Upgrades do
		if d.id == args.upgradeId then
			def = d
		end
	end
	if not def then
		return fail("Unknown upgrade.")
	end
	local level = (data.upgrades :: any)[def.id] or 0
	if level >= def.maxLevel then
		return fail("This upgrade is at the maximum level.")
	end
	local cost = def.cost(level)
	if data.gold < cost then
		return fail(NOT_ENOUGH_GOLD)
	end
	data.gold -= cost;
	(data.upgrades :: any)[def.id] = level + 1
	return { ok = true }
end

function handlers.StartFight(data, session, args, rng)
	if inFight(session) then
		return fail("You are in a fight.")
	end
	local index = args.monsterIndex
	if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #Config.Monsters then
		return fail("Unknown monster.")
	end
	if index > data.unlocked then
		return fail("Win against the monster before it first.")
	end
	local sword = equippedSword(data)
	if not sword then
		return fail("Equip a sword first.")
	end
	if sword.durability <= 0 then
		return fail("Your sword is broken. Repair it first.")
	end

	local log = {}
	local unbreaking = Sword.enchantLevel(sword, "Unbreaking")
	if unbreaking > 0 and rng:NextNumber() < Sword.enchantPower("Unbreaking", unbreaking) then
		table.insert(log, "Unbreaking keeps your durability.")
	else
		sword.durability -= 1
	end
	session.fight = Fight.new(sword, index)
	table.insert(log, 1, `A {Config.Monsters[index].name} appears!`)
	return { ok = true, log = log }
end

function handlers.FightTurn(data, session, args, rng)
	local fight = session.fight
	if not fight or fight.over then
		return fail("You are not in a fight.")
	end
	if type(args.action) ~= "string" then
		return fail("Unknown action.")
	end
	local r = Fight.turn(fight, args.action, rng)
	if r.error then
		return fail(r.error)
	end
	local result: Result = { ok = true, log = r.log, outcome = r.outcome }
	if r.outcome == "win" then
		local monster = Config.Monsters[fight.monsterIndex]
		local sword = equippedSword(data)
		local fortune = if sword then Sword.enchantLevel(sword, "Fortune") else 0
		local bonus = if fortune > 0 then Sword.enchantPower("Fortune", fortune) else 0
		local gold = math.floor(monster.gold * (1 + bonus) + 0.5)
		data.gold += gold
		result.gold = gold
		table.insert(r.log, `You get {gold} gold.`)
		if fight.monsterIndex == data.unlocked and data.unlocked < #Config.Monsters then
			data.unlocked += 1
			table.insert(r.log, `You unlock the {Config.Monsters[data.unlocked].name}.`)
		end
	end
	return result
end

function handlers.LeaveFight(_data, session, _args, _rng)
	if inFight(session) then
		return fail("Flee first to leave the fight.")
	end
	session.fight = nil
	return { ok = true }
end

function handlers.FinishGuide(data, _session, _args, _rng)
	data.guideDone = true
	return { ok = true }
end

-- Runs one action. It never throws for bad input from the client.
function Actions.run(data: Data, session: Session, name: any, args: any, rng: Odds.Rng): Result
	if type(name) ~= "string" then
		return fail("Unknown action.")
	end
	local handler = handlers[name]
	if not handler then
		return fail("Unknown action.")
	end
	if type(args) ~= "table" then
		return fail("Bad request.")
	end
	return handler(data, session, args, rng)
end

return Actions
