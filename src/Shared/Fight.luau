--!strict
-- A turn-based fight against one monster. Pure: no Roblox services.

local Config = require("./Config")
local Odds = require("./Odds")
local Sword = require("./Sword")

export type State = {
	monsterIndex: number,
	monsterName: string,
	monsterLevel: number,
	monsterMaxHealth: number,
	monsterHealth: number,
	playerMaxHealth: number,
	playerHealth: number,
	damage: number,
	enchants: { [string]: number }, -- enchantment id -> level
	cooldown: number, -- turns until Special is ready
	defending: boolean,
	frozen: boolean,
	burnTurns: number,
	burnDamage: number,
	turns: number,
	over: boolean,
}

export type Outcome = "win" | "lose" | "fled"
export type TurnResult = { log: { string }, outcome: Outcome?, error: string? }

local Fight = {}

Fight.Actions = { Attack = true, Defend = true, Special = true, Flee = true }

local BURN_TURNS = 3

function Fight.new(sword: Sword.Sword, monsterIndex: number): State
	local monster = Config.Monsters[monsterIndex]
	local enchants = {}
	for _, e in sword.enchants do
		enchants[e.id] = e.level
	end
	return {
		monsterIndex = monsterIndex,
		monsterName = monster.name,
		monsterLevel = monster.level,
		monsterMaxHealth = monster.health,
		monsterHealth = monster.health,
		playerMaxHealth = Config.PlayerHealth,
		playerHealth = Config.PlayerHealth,
		damage = Sword.damage(sword),
		enchants = enchants,
		cooldown = 0,
		defending = false,
		frozen = false,
		burnTurns = 0,
		burnDamage = 0,
		turns = 0,
		over = false,
	}
end

local function power(f: State, id: string): number
	local level = f.enchants[id]
	if not level then
		return 0
	end
	return Sword.enchantPower(id, level)
end

local function chance(f: State, id: string, rng: Odds.Rng): boolean
	local p = power(f, id)
	return p > 0 and rng:NextNumber() < p
end

local function round(x: number): number
	return math.floor(x + 0.5)
end

local function hitMonster(f: State, amount: number)
	f.monsterHealth = math.max(0, f.monsterHealth - amount)
end

local function playerAttack(f: State, special: boolean, rng: Odds.Rng, log: { string })
	local hit = f.damage * (if special then 2 else 1) + power(f, "Sharpness")
	local crit = chance(f, "Critical", rng)
	if crit then
		hit *= 2
	end
	hit = round(hit)
	hitMonster(f, hit)
	local verb = if special then "You use Special on" else "You hit"
	table.insert(log, `{verb} the {f.monsterName} for {hit} damage.{if crit then " Critical hit!" else ""}`)
	local dealt = hit

	if f.monsterHealth > 0 and chance(f, "Lightning", rng) then
		local extra = round(hit * 0.5)
		hitMonster(f, extra)
		dealt += extra
		table.insert(log, `Lightning strikes for {extra} more.`)
	end

	local steal = round(dealt * power(f, "Lifesteal"))
	if steal > 0 and f.playerHealth < f.playerMaxHealth then
		f.playerHealth = math.min(f.playerMaxHealth, f.playerHealth + steal)
		table.insert(log, `Lifesteal heals you for {steal}.`)
	end

	local fire = power(f, "Fire")
	if fire > 0 then
		f.burnTurns = BURN_TURNS
		f.burnDamage = round(fire)
	end

	if f.monsterHealth > 0 and chance(f, "Frost", rng) then
		f.frozen = true
		table.insert(log, `Frost freezes the {f.monsterName}.`)
	end
end

local function afterPlayer(f: State, log: { string })
	if f.burnTurns > 0 and f.monsterHealth > 0 then
		hitMonster(f, f.burnDamage)
		f.burnTurns -= 1
		table.insert(log, `Fire burns it for {f.burnDamage} more.`)
	end
	local execute = power(f, "Execute")
	if execute > 0 and f.monsterHealth > 0 and f.monsterHealth <= f.monsterMaxHealth * execute then
		f.monsterHealth = 0
		table.insert(log, `Execute finishes the {f.monsterName}!`)
	end
end

local function monsterAttack(f: State, rng: Odds.Rng, log: { string })
	if f.frozen then
		f.frozen = false
		table.insert(log, `The {f.monsterName} is frozen and loses its turn.`)
		return
	end
	local monster = Config.Monsters[f.monsterIndex]
	local spread = 1 + Config.MonsterAttackSpread * (2 * rng:NextNumber() - 1)
	local hit = monster.attack * spread
	if f.defending then
		hit *= 0.5
	end
	hit *= 1 - power(f, "Guard")
	hit = math.max(1, round(hit))
	f.playerHealth = math.max(0, f.playerHealth - hit)
	table.insert(log, `The {f.monsterName} hits you for {hit} damage.{if f.defending then " You block half." else ""}`)
end

-- Runs one turn. The fight state changes in place.
function Fight.turn(f: State, action: string, rng: Odds.Rng): TurnResult
	if f.over then
		return { log = {}, error = "The fight is over." }
	end
	if not Fight.Actions[action] then
		return { log = {}, error = "Unknown action." }
	end
	if action == "Special" and f.cooldown > 0 then
		return { log = {}, error = `Special is ready in {f.cooldown} turns.` }
	end

	local log: { string } = {}
	if action == "Flee" then
		f.over = true
		table.insert(log, "You flee from the fight.")
		return { log = log, outcome = "fled" }
	end

	f.turns += 1
	if f.cooldown > 0 then
		f.cooldown -= 1
	end
	f.defending = action == "Defend"
	if action == "Defend" then
		table.insert(log, "You raise your guard.")
	else
		playerAttack(f, action == "Special", rng, log)
		if action == "Special" then
			f.cooldown = Config.SpecialCooldown
		end
	end
	afterPlayer(f, log)

	if f.monsterHealth <= 0 then
		f.over = true
		table.insert(log, `You defeat the {f.monsterName}!`)
		return { log = log, outcome = "win" }
	end

	monsterAttack(f, rng, log)
	f.defending = false
	if f.playerHealth <= 0 then
		f.over = true
		table.insert(log, "You are defeated. You keep your sword.")
		return { log = log, outcome = "lose" }
	end
	return { log = log }
end

return Fight
