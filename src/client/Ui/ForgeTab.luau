--!strict
-- The Forge tab: three reels, the result card, the FORGE button, and the odds sheet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Odds = require(Shared:WaitForChild("Odds")) :: any
local Sword = require(Shared:WaitForChild("Sword")) :: any
local Forge = require(Shared:WaitForChild("Forge")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any
local Sheet = require(script.Parent.Sheet) :: any
local Reveal = require(script.Parent.Reveal) :: any

local ForgeTab = {}

local BANNER_ONE_IN = 100 -- A result of 1 in 100 or rarer gets a larger "1 in N" on the card.
local REEL_STOPS = { 0.3, 0.5, 0.7 } -- Seconds after the click when each reel stops.

-- The text of one enchantment, for example "Fire II  Burns for 6 damage for 3 turns".
function ForgeTab.enchantText(e): string
	local def = Sword.enchantDef(e.id)
	local level = Config.EnchantLevels[e.level].name
	local p = Sword.enchantPower(e.id, e.level)
	local effect = def.text:gsub("{p}", tostring(math.floor(p + 0.5))):gsub("{pct}", `{math.floor(p * 100 + 0.5)} %%`)
	return `<b><font color="{W.hex(Theme.tierColor(e.oneIn))}">{def.name} {level}</font></b>  {effect}`
end

-- Fills `parent` with the lines that describe a sword. Returns the last LayoutOrder.
function ForgeTab.fillDetails(parent: Instance, s, startOrder: number): number
	local order = startOrder
	local function line(text: string, color: Color3?)
		order += 1
		W.label({ Text = text, TextSize = 17, TextColor3 = color or Theme.Text, LayoutOrder = order, Parent = parent })
	end
	line(`Damage <b>{math.floor(Sword.damage(s) + 0.5)}</b>  ·  Durability <b>{s.durability}/{s.maxDurability}</b>`)
	line(
		`{Sword.materialDef(s).name} {Odds.format(s.odds.material)}  ·  {Sword.qualityDef(s).name} {Odds.format(s.odds.quality)}  ·  {Odds.plural(s.slots, "slot")} {Odds.format(s.odds.slots)}`,
		Theme.Muted
	)
	for _, e in s.enchants do
		line("+ " .. ForgeTab.enchantText(e))
	end
	for _ = #s.enchants + 1, s.slots do
		line("- Empty slot", Theme.Muted)
	end
	return order
end

-- A row in the odds sheet: a name on the left and a coloured "1 in N" chip on the right.
local function oddsRow(parent: Instance, name: string, row, order: number)
	local frame = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = order,
		Parent = parent,
	})
	local rest = if row.entry.oneIn == nil then "  (the rest)" else ""
	W.label({ Text = name .. rest, TextSize = 17, Size = UDim2.new(0.6, 0, 1, 0), Parent = frame })
	local n = 1 / row.p
	W.chip(Odds.format(n), Theme.tierColor(n), {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Parent = frame,
	})
end

local function openOdds(ctx: any)
	Sheet.open(ctx, "Real odds", function(body)
		local data = ctx.state.data
		local t = Forge.tables(data.upgrades)
		local order = 0
		local function note(text: string)
			order += 1
			W.label({ Text = text, TextColor3 = Theme.Muted, TextSize = 16, LayoutOrder = order, Parent = body })
		end
		local function section(title: string, rows, nameOf)
			order += 1
			W.label({ Text = title, Font = Theme.FontDisplay, TextSize = 20, TextColor3 = Theme.Gold, LayoutOrder = order, Parent = body })
			for _, row in rows do
				order += 1
				oddsRow(body, nameOf(row.entry), row, order)
			end
		end
		note("These are the real odds after your upgrades.")
		section("Material", t.material, function(e)
			return e.name
		end)
		section("Durability quality", t.quality, function(e)
			return `{e.name} (×{e.mult})`
		end)
		section("Enchantment slots", t.slots, function(e)
			return Odds.plural(e.count, "slot")
		end)
		note(`Each slot gets an enchantment at a {math.floor(Config.SlotFillChance * 100 + 0.5)} % chance.`)
		section("Enchantment", Forge.enchantTable(data.upgrades, {}), function(e)
			return e.name
		end)
		section("Enchantment level", t.level, function(e)
			return `Level {e.name}`
		end)
		return nil
	end)
end

-- One reel: a small card with a caption, a value, and its odds.
local function makeReel(parent: Instance, caption: string, order: number): (number) -> ()
	local reel = W.new("Frame", {
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	}, { W.corner(14), W.padding(6) })
	local stroke = W.stroke(Theme.Button, 2)
	stroke.Parent = reel
	W.label({
		Text = caption,
		Font = Theme.FontBold,
		TextSize = 12,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 14),
		Parent = reel,
	})
	local value = W.label({
		Text = "?",
		Font = Theme.FontDisplay,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 16),
		Parent = reel,
	})
	W.new("UITextSizeConstraint", { MaxTextSize = 22, Parent = value })
	local odds = W.label({
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 44),
		Parent = reel,
	})
	return function(text: string, color: Color3, oddsText: string)
		value.Text = text
		value.TextColor3 = color
		stroke.Color = color
		odds.Text = oddsText
	end :: any
end

function ForgeTab.create(page: Frame, ctx: any)
	local column = W.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		Parent = page,
	}, { W.maxWidth(560) })

	-- The scroll area holds everything except the FORGE button.
	local scroll = W.scroll({ Size = UDim2.new(1, 0, 1, -96), Parent = column })
	W.list(12).Parent = scroll
	W.padding(4, 6).Parent = scroll

	-- Row 1: pity counter and the Odds button.
	local infoRow = W.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = scroll })
	local pityLabel = W.label({
		Text = "",
		TextSize = 16,
		TextColor3 = Theme.Muted,
		Size = UDim2.new(1, -110, 1, 0),
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = infoRow,
	})
	W.button("Odds", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(100, 40),
		TextSize = 16,
		Parent = infoRow,
	}, function()
		openOdds(ctx)
	end)

	-- Row 2: the three reels.
	local reelRow = W.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 72), LayoutOrder = 2, Parent = scroll }, {
		W.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 1, 0),
			CellPadding = UDim2.fromOffset(9, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local setters: { any } = {
		makeReel(reelRow, "MATERIAL", 1),
		makeReel(reelRow, "QUALITY", 2),
		makeReel(reelRow, "SLOTS", 3),
	}

	-- Row 3: the result card.
	local card = W.card({ BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 3, Parent = scroll })
	W.list(6).Parent = card
	local cardStroke = W.stroke(Theme.Button, 3)
	cardStroke.Parent = card
	local cardGlow = W.new("UIGradient", {
		Color = ColorSequence.new(Theme.PanelLight, Theme.PanelLight),
		Rotation = 90,
		Parent = card,
	})
	local chipHolder = W.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = card })
	local nameLabel = W.label({
		Text = "Your forge is ready",
		Font = Theme.FontDisplay,
		TextSize = 30,
		LayoutOrder = 2,
		Parent = card,
	})
	local rarityLabel = W.label({
		Text = "Tap FORGE to roll a sword.",
		Font = Theme.FontDisplay,
		TextSize = 22,
		TextColor3 = Theme.Muted,
		LayoutOrder = 3,
		Parent = card,
	})
	local details = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = card,
	}, { W.list(4) })

	local function showCard(s)
		local rarity = Sword.rarity(s)
		local color = Theme.tierColor(rarity)
		W.clear(chipHolder)
		W.chip(string.upper(Odds.tierName(rarity)), color, { Parent = chipHolder })
		nameLabel.Text = Sword.name(s)
		nameLabel.TextColor3 = color
		rarityLabel.Text = Odds.format(rarity)
		rarityLabel.TextSize = if rarity >= BANNER_ONE_IN then 36 else 28
		rarityLabel.TextColor3 = color
		cardStroke.Color = color
		cardGlow.Color = ColorSequence.new(color:Lerp(Theme.PanelLight, 0.7), Theme.PanelLight)
		W.clear(details)
		ForgeTab.fillDetails(details, s, 0)
		W.pop(card, 0.85)
	end

	-- The FORGE button stays at the bottom, in the thumb zone.
	local busy = false
	local skip = false
	local forgeButton
	forgeButton = W.button("FORGE", {
		primary = true,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -12),
		Size = UDim2.new(1, 0, 0, 72),
		Font = Theme.FontDisplay,
		TextSize = 30,
		Parent = column,
	}, function()
		if busy then
			skip = true -- A second tap skips the animation.
			return
		end
		busy = true
		skip = false
		forgeButton.Text = "TAP TO SKIP"
		-- The server decides the result before the animation starts.
		local result = ctx.request("Forge")
		if not result.ok then
			busy = false
			ctx.render()
			return
		end
		local s = result.sword
		local finals = {
			{ Sword.materialDef(s).name, s.odds.material },
			{ Sword.qualityDef(s).name, s.odds.quality },
			{ Odds.plural(s.slots, "slot"), s.odds.slots },
		}
		local start = os.clock()
		local stopped = { false, false, false }
		while not (stopped[1] and stopped[2] and stopped[3]) do
			local t = os.clock() - start
			for i = 1, 3 do
				if not stopped[i] then
					if skip or t >= REEL_STOPS[i] then
						stopped[i] = true
						setters[i](finals[i][1], Theme.tierColor(finals[i][2]), Odds.format(finals[i][2]))
						W.sound("Tick", 0.4)
					else
						local m = Config.Materials[math.random(1, #Config.Materials)]
						setters[i](if i == 1 then m.name else "· · ·", Theme.Tiers[math.random(1, 6)], "")
					end
				end
			end
			task.wait(0.05)
		end
		showCard(s)
		local rarity = Sword.rarity(s)
		if rarity >= Config.RareFlashOneIn then
			Reveal.show(ctx, rarity, Sword.name(s))
		end
		busy = false
		ctx.render()
	end)
	ctx.targets.ForgeButton = forgeButton

	local function update(state)
		local data = state.data
		local full = #data.swords >= Config.MaxSwords
		local left = math.max(1, Config.PityLimit - data.pity)
		pityLabel.Text = `Steel or better in <b>{Odds.plural(left, "forge")}</b>  ·  {#data.swords}/{Config.MaxSwords} swords`
		if busy then
			return
		end
		forgeButton.Text = if full then "SWORD LIST FULL" else `FORGE  ·  {Config.ForgeCost} gold`
		W.setEnabled(forgeButton, not full and data.gold >= Config.ForgeCost)
	end

	return { update = update }
end

return ForgeTab
