--!strict
-- Roll tables with "1 in N" odds. Pure: no Roblox services.

export type Entry = { id: string, oneIn: number?, [string]: any }
export type Row = { entry: Entry, p: number }
export type Rng = { NextNumber: (self: any) -> number }

local Odds = {}

local TIER_LIMITS = { 10, 100, 1000, 10000, 100000 }

-- Builds a table of chances. `mult` multiplies each rare entry.
-- The rest entry gets the remaining chance, but never less than `minRest`.
-- A table with no rest entry is scaled so that the sum is 1.
function Odds.build(entries: { Entry }, mult: number, minRest: number): { Row }
	local rows: { Row } = {}
	local rareSum = 0
	local restRow: Row? = nil
	for _, entry in entries do
		local row = { entry = entry, p = 0 }
		if entry.oneIn then
			row.p = mult / entry.oneIn
			rareSum += row.p
		else
			restRow = row
		end
		table.insert(rows, row)
	end

	local rareTarget = if restRow then math.min(rareSum, 1 - minRest) else 1
	if rareSum > 0 and rareTarget ~= rareSum then
		local scale = rareTarget / rareSum
		for _, row in rows do
			if row ~= restRow then
				row.p *= scale
			end
		end
	end
	if restRow then
		restRow.p = 1 - rareTarget
	end
	return rows
end

-- Picks one entry. Returns the entry and its chance.
function Odds.roll(rows: { Row }, rng: Rng): (Entry, number)
	local r = rng:NextNumber()
	local acc = 0
	for _, row in rows do
		acc += row.p
		if r < acc then
			return row.entry, row.p
		end
	end
	local last = rows[#rows]
	return last.entry, last.p
end

-- Finds the chance of one entry in a built table.
function Odds.chanceOf(rows: { Row }, id: string): number
	for _, row in rows do
		if row.entry.id == id then
			return row.p
		end
	end
	return 0
end

local function withCommas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

-- Rounds N to a readable number: one decimal below 10, a whole number below
-- 1,000, and three significant digits above that.
function Odds.formatNumber(n: number): string
	if n < 10 then
		local rounded = math.floor(n * 10 + 0.5) / 10
		if rounded == math.floor(rounded) then
			return tostring(math.floor(rounded))
		end
		return string.format("%.1f", rounded)
	elseif n < 1000 then
		return tostring(math.floor(n + 0.5))
	end
	local digits = math.floor(math.log10(n)) + 1
	local unit = 10 ^ (digits - 3)
	return withCommas(math.floor(n / unit + 0.5) * unit)
end

function Odds.format(n: number): string
	return "1 in " .. Odds.formatNumber(n)
end

-- The colour tier of a "1 in N" value: 1 (common) to 6 (rarest).
function Odds.tier(n: number): number
	local tier = 1
	for _, limit in TIER_LIMITS do
		if n >= limit then
			tier += 1
		end
	end
	return tier
end

return Odds
