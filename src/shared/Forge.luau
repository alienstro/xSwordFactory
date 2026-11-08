--!strict
-- The forge: rolls a new sword and rolls enchantments. Pure: no Roblox services.

local Config = require("./Config")
local Odds = require("./Odds")
local Sword = require("./Sword")

export type Upgrades = { Luck: number, Slots: number, Durability: number }
export type Tables = {
	material: { Odds.Row },
	quality: { Odds.Row },
	slots: { Odds.Row },
	level: { Odds.Row },
}

local Forge = {}

function Forge.mult(upgrades: Upgrades, id: string): number
	for _, def in Config.Upgrades do
		if def.id == id then
			return def.mult((upgrades :: any)[id] or 0)
		end
	end
	error(`unknown upgrade {id}`)
end

-- The real odds of each roll table after all upgrades.
function Forge.tables(upgrades: Upgrades): Tables
	local luck = Forge.mult(upgrades, "Luck")
	return {
		material = Odds.build(Config.Materials, luck, Config.MinRest),
		quality = Odds.build(Config.Qualities, Forge.mult(upgrades, "Durability"), Config.MinRest),
		slots = Odds.build(Config.SlotCounts, luck * Forge.mult(upgrades, "Slots"), Config.MinRest),
		level = Odds.build(Config.EnchantLevels, luck, Config.MinRest),
	}
end

-- The enchantment table without the enchantments in `exclude`.
function Forge.enchantTable(upgrades: Upgrades, exclude: { [string]: boolean }): { Odds.Row }
	local entries = {}
	for _, def in Config.Enchants do
		if not exclude[def.id] then
			table.insert(entries, def)
		end
	end
	if #entries == 0 then
		return {}
	end
	return Odds.build(entries, Forge.mult(upgrades, "Luck"), Config.MinRest)
end

-- The material table that the pity counter uses: only the rare materials.
function Forge.pityTable(upgrades: Upgrades): { Odds.Row }
	local entries = {}
	for _, def in Config.Materials do
		if def.oneIn and def.oneIn >= Config.PityMinOneIn then
			table.insert(entries, def)
		end
	end
	return Odds.build(entries, Forge.mult(upgrades, "Luck"), Config.MinRest)
end

local function owned(sword: { enchants: { Sword.Enchant } }): { [string]: boolean }
	local set = {}
	for _, e in sword.enchants do
		set[e.id] = true
	end
	return set
end

-- Rolls one enchantment that the sword does not have yet. Returns nil if none is left.
function Forge.rollEnchant(upgrades: Upgrades, sword: { enchants: { Sword.Enchant } }, rng: Odds.Rng): Sword.Enchant?
	local rows = Forge.enchantTable(upgrades, owned(sword))
	if #rows == 0 then
		return nil
	end
	local def, pType = Odds.roll(rows, rng)
	local levelDef, pLevel = Odds.roll(Forge.tables(upgrades).level, rng)
	return { id = def.id, level = levelDef.level, oneIn = 1 / (pType * pLevel) }
end

local function isRare(material): boolean
	return material.oneIn ~= nil and material.oneIn >= Config.PityMinOneIn
end

-- Rolls a new sword. Returns the sword and the new pity counter.
function Forge.roll(upgrades: Upgrades, pity: number, rng: Odds.Rng, id: string): (Sword.Sword, number)
	local t = Forge.tables(upgrades)

	local material
	if pity + 1 >= Config.PityLimit then
		material = Odds.roll(Forge.pityTable(upgrades), rng)
	else
		material = Odds.roll(t.material, rng)
	end
	local quality, pQuality = Odds.roll(t.quality, rng)
	local slots, pSlots = Odds.roll(t.slots, rng)
	local maxDurability = math.max(1, math.floor(material.durability * quality.mult + 0.5))

	local sword: Sword.Sword = {
		id = id,
		material = material.id,
		quality = quality.id,
		maxDurability = maxDurability,
		durability = maxDurability,
		slots = slots.count,
		enchants = {},
		enhance = 0,
		-- The stored odds are the odds of the normal table, also for a pity roll.
		odds = {
			material = 1 / Odds.chanceOf(t.material, material.id),
			quality = 1 / pQuality,
			slots = 1 / pSlots,
		},
	}

	for _ = 1, slots.count do
		if rng:NextNumber() < Config.SlotFillChance then
			local enchant = Forge.rollEnchant(upgrades, sword, rng)
			if enchant then
				table.insert(sword.enchants, enchant)
			end
		end
	end

	local newPity = if isRare(material) then 0 else pity + 1
	return sword, newPity
end

return Forge
