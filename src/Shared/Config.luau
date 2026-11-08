--!strict
-- All tuning numbers of Sword Factory. Change the numbers here only.
-- An entry with no `oneIn` is "the rest": it gets the remaining chance.

local Config = {}

Config.StartingGold = 200
Config.MaxSwords = 50
Config.ForgeCost = 25
Config.RareFlashOneIn = 1000 -- A roll of 1 in this number or rarer gets a flash and a sound.

-- Pity: after this many forges with no material of 1 in PityMinOneIn or rarer,
-- the next forge gives one.
Config.PityLimit = 60
Config.PityMinOneIn = 25

-- The rest entry of a table never falls below this chance after upgrades.
Config.MinRest = 0.1

-- Chance that the forge fills each slot with an enchantment.
Config.SlotFillChance = 1 / 4

Config.Materials = {
	{ id = "Wood", name = "Wood", damage = 5, durability = 10 },
	{ id = "Stone", name = "Stone", oneIn = 4, damage = 8, durability = 15 },
	{ id = "Iron", name = "Iron", oneIn = 10, damage = 12, durability = 20 },
	{ id = "Steel", name = "Steel", oneIn = 25, damage = 18, durability = 25 },
	{ id = "Silver", name = "Silver", oneIn = 100, damage = 26, durability = 30 },
	{ id = "Gold", name = "Gold", oneIn = 250, damage = 36, durability = 30 },
	{ id = "Mithril", name = "Mithril", oneIn = 1000, damage = 50, durability = 40 },
	{ id = "Obsidian", name = "Obsidian", oneIn = 2500, damage = 70, durability = 50 },
	{ id = "Dragonbone", name = "Dragonbone", oneIn = 10000, damage = 100, durability = 60 },
	{ id = "Starmetal", name = "Starmetal", oneIn = 100000, damage = 150, durability = 80 },
}

Config.Qualities = {
	{ id = "Worn", name = "Worn", mult = 0.8 },
	{ id = "Normal", name = "Normal", oneIn = 2, mult = 1.0 },
	{ id = "Sturdy", name = "Sturdy", oneIn = 10, mult = 1.5 },
	{ id = "Masterwork", name = "Masterwork", oneIn = 100, mult = 2.5 },
}

Config.SlotCounts = {
	{ id = "0", count = 0 },
	{ id = "1", count = 1, oneIn = 3 },
	{ id = "2", count = 2, oneIn = 10 },
	{ id = "3", count = 3, oneIn = 50 },
	{ id = "4", count = 4, oneIn = 500 },
	{ id = "5", count = 5, oneIn = 5000 },
}

-- The power of an enchantment at level L is base + perLevel * L.
-- `text` shows in the UI. `{p}` is the power as a number, `{pct}` as a percent.
Config.Enchants = {
	{ id = "Sharpness", name = "Sharpness", base = 0, perLevel = 3, text = "+{p} damage to each hit" },
	{ id = "Fire", name = "Fire", oneIn = 8, base = 0, perLevel = 3, text = "Burns for {p} damage for 3 turns" },
	{ id = "Frost", name = "Frost", oneIn = 15, base = 0.10, perLevel = 0.05, text = "{pct} chance to freeze the monster" },
	{ id = "Lifesteal", name = "Lifesteal", oneIn = 40, base = 0, perLevel = 0.05, text = "Heals {pct} of the damage" },
	{ id = "Critical", name = "Critical", oneIn = 40, base = 0.10, perLevel = 0.04, text = "{pct} chance of double damage" },
	{ id = "Lightning", name = "Lightning", oneIn = 100, base = 0.10, perLevel = 0.05, text = "{pct} chance of a second hit" },
	{ id = "Guard", name = "Guard", oneIn = 100, base = 0, perLevel = 0.05, text = "Takes {pct} less damage" },
	{ id = "Fortune", name = "Fortune", oneIn = 250, base = 0, perLevel = 0.10, text = "+{pct} gold after a win" },
	{ id = "Unbreaking", name = "Unbreaking", oneIn = 250, base = 0, perLevel = 0.15, text = "{pct} chance to keep durability" },
	{ id = "Execute", name = "Execute", oneIn = 2500, base = 0.05, perLevel = 0.02, text = "Kills the monster below {pct} health" },
}

Config.EnchantLevels = {
	{ id = "1", level = 1, name = "I" },
	{ id = "2", level = 2, name = "II", oneIn = 4 },
	{ id = "3", level = 3, name = "III", oneIn = 20 },
	{ id = "4", level = 4, name = "IV", oneIn = 200 },
	{ id = "5", level = 5, name = "V", oneIn = 2000 },
}

Config.MaxEnhance = 10
Config.EnhanceDamagePerLevel = 0.10
-- EnhanceChance[n] is the chance to go from +(n-1) to +n.
Config.EnhanceChance = { 1.0, 0.95, 0.90, 0.80, 0.70, 0.60, 0.50, 0.40, 0.30, 0.20 }

function Config.enhanceCost(toLevel: number): number
	return math.floor(15 * toLevel ^ 1.6 + 0.5)
end

function Config.enchantCost(filledSlots: number): number
	return math.floor(40 * (filledSlots + 1) ^ 1.8 + 0.5)
end

-- Repair cost for each missing point of durability, by material index (1 = Wood).
function Config.repairCostPerPoint(materialIndex: number): number
	return 1 + 0.5 * (materialIndex - 1)
end

function Config.salvageValue(rarity: number, enhance: number): number
	return math.floor(5 * rarity ^ 0.35) + enhance * 10
end

-- Forge upgrades. `mult(level)` multiplies the chance of each rare entry.
Config.Upgrades = {
	{
		id = "Luck",
		name = "Luck",
		text = "Rarer materials, slots, and enchantments",
		maxLevel = 10,
		cost = function(level: number): number
			return math.floor(100 * 1.8 ^ level + 0.5)
		end,
		mult = function(level: number): number
			return 1 + 0.2 * level
		end,
	},
	{
		id = "Slots",
		name = "Enchant Slots",
		text = "More enchantment slots",
		maxLevel = 10,
		cost = function(level: number): number
			return math.floor(80 * 1.7 ^ level + 0.5)
		end,
		mult = function(level: number): number
			return 1 + 0.25 * level
		end,
	},
	{
		id = "Durability",
		name = "Durability",
		text = "Better durability quality",
		maxLevel = 10,
		cost = function(level: number): number
			return math.floor(60 * 1.6 ^ level + 0.5)
		end,
		mult = function(level: number): number
			return 1 + 0.25 * level
		end,
	},
}

Config.PlayerHealth = 100
Config.SpecialCooldown = 3
Config.MonsterAttackSpread = 0.2 -- The monster hit is attack × (1 ± this number).

-- Health is 6 hits of the fitting material. A fitting sword takes at most 90 damage.
Config.Monsters = {
	{ name = "Slime", icon = "💧", level = 1, health = 30, attack = 6, gold = 15 },
	{ name = "Rat King", icon = "🐀", level = 2, health = 48, attack = 7, gold = 30 },
	{ name = "Goblin", icon = "👺", level = 3, health = 72, attack = 8, gold = 55 },
	{ name = "Wolf", icon = "🐺", level = 4, health = 108, attack = 9, gold = 90 },
	{ name = "Orc", icon = "👹", level = 5, health = 156, attack = 10, gold = 140 },
	{ name = "Troll", icon = "🤢", level = 6, health = 216, attack = 11, gold = 210 },
	{ name = "Wraith", icon = "👻", level = 7, health = 300, attack = 12, gold = 320 },
	{ name = "Stone Golem", icon = "🗿", level = 8, health = 420, attack = 13, gold = 480 },
	{ name = "Demon", icon = "😈", level = 9, health = 600, attack = 14, gold = 720 },
	{ name = "Elder Dragon", icon = "🐉", level = 10, health = 900, attack = 15, gold = 1500, boss = true },
}

-- Requests for each second, and the largest burst.
Config.RequestRate = 8
Config.RequestBurst = 15

return Config
