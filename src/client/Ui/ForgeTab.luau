--!strict
-- The Forge tab: the Forge button, the result card, the pity counter, and the real odds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Odds = require(Shared:WaitForChild("Odds")) :: any
local Sword = require(Shared:WaitForChild("Sword")) :: any
local Forge = require(Shared:WaitForChild("Forge")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

local ForgeTab = {}

local function oddsText(row): string
	local n = 1 / row.p
	return `<font color="{W.hex(Theme.tierColor(n))}">{Odds.format(n)}</font>`
end

-- Text lines that describe a sword. Shared with the Swords tab.
function ForgeTab.describe(s): { string }
	local lines = {
		`Rarity: <b><font color="{W.hex(Theme.tierColor(Sword.rarity(s)))}">{Odds.format(Sword.rarity(s))}</font></b>`,
		`Material: {Sword.materialDef(s).name} ({Odds.format(s.odds.material)}) · Damage {math.floor(Sword.damage(s) + 0.5)}`,
		`Quality: {Sword.qualityDef(s).name} ({Odds.format(s.odds.quality)}) · Durability {s.durability}/{s.maxDurability}`,
		`Slots: {s.slots} ({Odds.format(s.odds.slots)})`,
	}
	for _, e in s.enchants do
		local def = Sword.enchantDef(e.id)
		local level = Config.EnchantLevels[e.level].name
		local p = Sword.enchantPower(e.id, e.level)
		local text = def.text:gsub("{p}", tostring(math.floor(p + 0.5))):gsub("{pct}", `{math.floor(p * 100 + 0.5)} %%`)
		table.insert(
			lines,
			`  + <font color="{W.hex(Theme.tierColor(e.oneIn))}">{def.name} {level}</font> ({Odds.format(e.oneIn)}): {text}`
		)
	end
	for _ = #s.enchants + 1, s.slots do
		table.insert(lines, `  - <font color="{W.hex(Theme.Muted)}">Empty slot</font>`)
	end
	return lines
end

function ForgeTab.create(page: Frame, ctx: any)
	-- Left side: the forge.
	local left = W.panel({ Size = UDim2.new(0.55, -6, 1, 0), Parent = page })
	W.list(10).Parent = left

	W.label({ Text = "The Forge", Font = Theme.FontBold, TextSize = 24, LayoutOrder = 1, Parent = left })
	local pityLabel = W.label({ Text = "", TextColor3 = Theme.Muted, LayoutOrder = 2, Parent = left })

	local resultCard = W.panel({
		BackgroundColor3 = Theme.PanelLight,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = left,
	})
	W.list(4).Parent = resultCard
	local resultName = W.label({
		Text = "Click Forge to make a sword.",
		Font = Theme.FontBold,
		TextSize = 26,
		LayoutOrder = 1,
		Parent = resultCard,
	})
	local resultBody = W.label({ Text = "", TextSize = 17, LayoutOrder = 2, Parent = resultCard })

	local busy = false
	local forgeButton
	forgeButton = W.button("Forge", {
		BackgroundColor3 = Theme.Accent,
		TextColor3 = Theme.Background,
		TextSize = 24,
		Size = UDim2.new(1, 0, 0, 60),
		LayoutOrder = 4,
		Parent = left,
	}, function()
		if busy then
			return
		end
		busy = true
		W.setEnabled(forgeButton, false)
		resultBody.Text = ""
		-- The server decides the result before the animation starts.
		local result = ctx.request("Forge")
		if result.ok then
			for i = 1, 14 do
				local m = Config.Materials[math.random(1, #Config.Materials)]
				resultName.Text = `{m.name} Sword`
				resultName.TextColor3 = Theme.Tiers[math.random(1, 6)]
				task.wait(0.03 + i * 0.006)
			end
			local s = result.sword
			resultName.Text = Sword.name(s)
			resultName.TextColor3 = Theme.tierColor(Sword.rarity(s))
			resultBody.Text = table.concat(ForgeTab.describe(s), "\n")
			if Sword.rarity(s) >= Config.RareFlashOneIn or s.odds.material >= Config.RareFlashOneIn then
				ctx.flash(Theme.tierColor(Sword.rarity(s)))
				ctx.toast(`A {Odds.format(Sword.rarity(s))} sword!`, Theme.tierColor(Sword.rarity(s)))
			end
		end
		busy = false
		ctx.render()
	end)
	ctx.targets.ForgeButton = forgeButton

	W.label({
		Text = "Equip a sword in the Swords tab. Then fight with it in the Fight tab.",
		TextColor3 = Theme.Muted,
		TextSize = 16,
		LayoutOrder = 5,
		Parent = left,
	})

	-- Right side: the real odds after all upgrades.
	local right = W.panel({
		Size = UDim2.new(0.45, -6, 1, 0),
		Position = UDim2.new(0.55, 6, 0, 0),
		Parent = page,
	})
	W.label({ Text = "Real odds", Font = Theme.FontBold, TextSize = 22, Parent = right })
	local oddsScroll = W.scroll({ Size = UDim2.new(1, 0, 1, -32), Position = UDim2.new(0, 0, 0, 32), Parent = right })
	local oddsLabel = W.label({ Text = "", TextSize = 16, Parent = oddsScroll })

	local function section(title: string, rows, nameOf): string
		local out = { `<b>{title}</b>` }
		for _, row in rows do
			local rest = if row.entry.oneIn == nil then " · the rest" else ""
			table.insert(out, `{nameOf(row.entry)}: {oddsText(row)}{rest}`)
		end
		return table.concat(out, "\n")
	end

	local function update(state)
		local data = state.data
		local full = #data.swords >= Config.MaxSwords
		forgeButton.Text = if full then "Sword list is full" else `Forge · {Config.ForgeCost} gold`
		if not busy then
			W.setEnabled(forgeButton, not full and data.gold >= Config.ForgeCost)
		end
		local left_ = math.max(1, Config.PityLimit - data.pity)
		pityLabel.Text = `Steel or better in {left_} forges · {#data.swords}/{Config.MaxSwords} swords`

		local t = Forge.tables(data.upgrades)
		local slotChance = math.floor(Config.SlotFillChance * 100 + 0.5)
		oddsLabel.Text = table.concat({
			section("Material", t.material, function(e)
				return e.name
			end),
			section("Durability quality", t.quality, function(e)
				return `{e.name} (×{e.mult})`
			end),
			section("Enchantment slots", t.slots, function(e)
				return `{e.count} slots`
			end),
			`Each slot gets an enchantment at a {slotChance} % chance.`,
			section("Enchantments", Forge.enchantTable(data.upgrades, {}), function(e)
				return e.name
			end),
			section("Enchantment level", t.level, function(e)
				return `Level {e.name}`
			end),
		}, "\n\n")
	end

	return { update = update }
end

return ForgeTab
