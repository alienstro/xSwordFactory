--!strict
-- Rules for one sword. Pure: no Roblox services.

local Config = require("./Config")

export type Enchant = { id: string, level: number, oneIn: number }
export type Sword = {
	id: string,
	material: string,
	quality: string,
	maxDurability: number,
	durability: number,
	slots: number,
	enchants: { Enchant },
	enhance: number,
	-- The "1 in N" value of each rolled part.
	odds: { material: number, quality: number, slots: number },
}

local Sword = {}

local function findIndex(list: { any }, id: string): number
	for i, item in list do
		if item.id == id then
			return i
		end
	end
	error(`unknown id {id}`)
end

function Sword.materialIndex(s: Sword): number
	return findIndex(Config.Materials, s.material)
end

function Sword.materialDef(s: Sword)
	return Config.Materials[Sword.materialIndex(s)]
end

function Sword.qualityDef(s: Sword)
	return Config.Qualities[findIndex(Config.Qualities, s.quality)]
end

function Sword.enchantDef(id: string)
	return Config.Enchants[findIndex(Config.Enchants, id)]
end

function Sword.name(s: Sword): string
	local base = Sword.materialDef(s).name .. " Sword"
	if s.enhance > 0 then
		return `{base} +{s.enhance}`
	end
	return base
end

-- The damage of one hit before enchantments.
function Sword.damage(s: Sword): number
	return Sword.materialDef(s).damage * (1 + Config.EnhanceDamagePerLevel * s.enhance)
end

-- The product of the "1 in N" values of all rolled parts.
function Sword.rarity(s: Sword): number
	local r = s.odds.material * s.odds.quality * s.odds.slots
	for _, e in s.enchants do
		r *= e.oneIn
	end
	return r
end

function Sword.emptySlots(s: Sword): number
	return s.slots - #s.enchants
end

-- The level of an enchantment on the sword, or 0 if the sword does not have it.
function Sword.enchantLevel(s: Sword, id: string): number
	for _, e in s.enchants do
		if e.id == id then
			return e.level
		end
	end
	return 0
end

function Sword.enchantPower(id: string, level: number): number
	local def = Sword.enchantDef(id)
	return def.base + def.perLevel * level
end

function Sword.enhanceCost(toLevel: number): number
	return Config.enhanceCost(toLevel)
end

function Sword.enchantCost(s: Sword): number
	return Config.enchantCost(#s.enchants)
end

function Sword.repairCost(s: Sword): number
	local missing = s.maxDurability - s.durability
	return math.ceil(missing * Config.repairCostPerPoint(Sword.materialIndex(s)))
end

function Sword.salvageValue(s: Sword): number
	return Config.salvageValue(Sword.rarity(s), s.enhance)
end

return Sword
