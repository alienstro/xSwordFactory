--!strict
-- The Forge tab: the result card with its three rolls, the FORGE button, and the odds sheet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Odds = require(Shared:WaitForChild("Odds")) :: any
local Sword = require(Shared:WaitForChild("Sword")) :: any
local Forge = require(Shared:WaitForChild("Forge")) :: any
local AutoDelete = require(Shared:WaitForChild("AutoDelete")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any
local Sheet = require(script.Parent.Sheet) :: any
local Reveal = require(script.Parent.Reveal) :: any
local AutoForgeSheet = require(script.Parent.AutoForgeSheet) :: any

local ForgeTab = {}

local STOP_PITCH = { 0.9, 1.0, 1.12 } -- Each reel stop sounds a little higher, so the tension grows.
local SPIN_TICK = 0.08 -- Seconds between two ticks while the reels turn.
local REEL_STOPS = { 0.3, 0.5, 0.7 } -- Seconds after the click when each roll stops.
local AUTO_SPEED = 0.5 -- In auto forge, the reels stop in half the time.
local AUTO_PAUSE = 0.35 -- Seconds between two forges in auto forge, so the player can read the result.
local AUTO_WIDTH = 112 -- The width of the Auto switch next to FORGE.

-- The text of one enchantment, for example "Fire II  Burns for 6 damage for 3 turns".
function ForgeTab.enchantText(e): string
	local def = Sword.enchantDef(e.id)
	local level = Config.EnchantLevels[e.level].name
	local p = Sword.enchantPower(e.id, e.level)
	local effect = def.text:gsub("{p}", tostring(math.floor(p + 0.5))):gsub("{pct}", `{math.floor(p * 100 + 0.5)} %%`)
	return `<b><font color="{W.hex(Theme.tierColor(e.oneIn))}">{def.name} {level}</font></b>  <font color="{W.hex(Theme.Muted)}">{effect}</font>`
end

-- A stat: a small caption with a value under it.
local function stat(parent: Instance, caption: string, order: number): TextLabel
	local box = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = order,
		Parent = parent,
	}, { W.list(2) })
	W.caption(caption, { Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, Parent = box })
	return W.label({
		Text = "",
		Font = Theme.FontMono,
		TextSize = Theme.TextSize.Lead,
		TextWrapped = false,
		Size = UDim2.new(0, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = box,
	})
end

-- Fills `parent` with the lines that describe a sword. Returns the last LayoutOrder.
-- Set `showOdds` to false where the rolls are already on screen.
function ForgeTab.fillDetails(parent: Instance, s, startOrder: number, showOdds: boolean?): number
	local order = startOrder + 1
	local stats = W.new("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	}, { W.list(Theme.Space.XL, true) })
	stat(stats, "Damage", 1).Text = tostring(math.floor(Sword.damage(s) + 0.5))
	stat(stats, "Durability", 2).Text = `{s.durability}/{s.maxDurability}`
	stat(stats, "Slots", 3).Text = `{#s.enchants}/{s.slots}`

	local function line(text: string, color: Color3?)
		order += 1
		W.label({ Text = text, TextSize = Theme.TextSize.Small, TextColor3 = color or Theme.Text, LayoutOrder = order, Parent = parent })
	end
	if showOdds ~= false then
		line(
			`{Sword.materialDef(s).name} {Odds.format(s.odds.material)}  ·  {Sword.qualityDef(s).name} {Odds.format(s.odds.quality)}  ·  {Odds.plural(s.slots, "slot")} {Odds.format(s.odds.slots)}`,
			Theme.Muted
		)
	end
	for _, e in s.enchants do
		line(ForgeTab.enchantText(e))
	end
	for _ = #s.enchants + 1, s.slots do
		line("Empty slot", Theme.Faint)
	end
	return order
end

-- A row in the odds sheet: a name on the left and the "1 in N" on the right.
local function oddsRow(parent: Instance, name: string, row, order: number)
	local frame = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = order,
		Parent = parent,
	})
	local rest = if row.entry.oneIn == nil then `  <font color="{W.hex(Theme.Faint)}">(the rest)</font>` else ""
	W.label({ Text = name .. rest, TextSize = Theme.TextSize.Body, Size = UDim2.new(0.65, 0, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, Parent = frame })
	local n = 1 / row.p
	W.label({
		Text = Odds.format(n),
		Font = Theme.FontMono,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.tierColor(n),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.35, 0, 1, 0),
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
			W.label({ Text = text, TextColor3 = Theme.Muted, TextSize = Theme.TextSize.Small, LayoutOrder = order, Parent = body })
		end
		local function section(title: string, rows, nameOf)
			order += 1
			W.caption(title, { TextColor3 = Theme.Muted, LayoutOrder = order, Parent = body })
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

-- One roll in the strip: a caption, a value, and its odds.
local function makeRoll(parent: Instance, caption: string, order: number): (string, Color3, string) -> ()
	local cell = W.new("Frame", {
		Name = caption,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	}, { W.list(2) })
	W.caption(caption, { Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.None, LayoutOrder = 1, Parent = cell })
	local value = W.label({
		Text = "—",
		Font = Theme.FontBold,
		TextSize = Theme.TextSize.Lead,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.None,
		LayoutOrder = 2,
		Parent = cell,
	})
	local odds = W.label({
		Text = "",
		Font = Theme.FontMono,
		TextSize = Theme.TextSize.Caption,
		TextColor3 = Theme.Faint,
		Size = UDim2.new(1, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.None,
		LayoutOrder = 3,
		Parent = cell,
	})
	return function(text: string, color: Color3, oddsText: string)
		value.Text = text
		value.TextColor3 = color
		odds.Text = oddsText
		odds.TextColor3 = if oddsText == "" then Theme.Faint else color
	end
end

function ForgeTab.create(page: Frame, ctx: any)
	local column = W.column(page)

	-- The scroll area holds everything except the FORGE button.
	local scroll = W.scroll({ Name = "Body", Size = UDim2.new(1, 0, 1, -(Theme.PrimaryHeight + 2 * Theme.Space.M)), Parent = column })
	W.list(Theme.Space.M).Parent = scroll
	W.padding(0, Theme.Space.XS).Parent = scroll

	-- Row 1: the pity counter and the Odds link.
	local infoRow = W.new("Frame", { Name = "Info", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 1, Parent = scroll })
	local pityLabel = W.label({
		Name = "Pity",
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Muted,
		Size = UDim2.new(1, -200, 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = infoRow,
	})
	W.button("Auto rules", {
		Name = "AutoRulesButton",
		variant = "quiet",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -96, 0.5, 0),
		Size = UDim2.fromOffset(100, 32),
		TextSize = Theme.TextSize.Small,
		Parent = infoRow,
	}, function()
		AutoForgeSheet.open(ctx)
	end)
	W.button("See odds", {
		Name = "OddsButton",
		variant = "quiet",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(88, 32),
		TextSize = Theme.TextSize.Small,
		Parent = infoRow,
	}, function()
		openOdds(ctx)
	end)

	-- Row 2: the result card. The roll strip is on top, the sword under it.
	local card, body, setAccent = W.accentCard({ Name = "Result", LayoutOrder = 2, Parent = scroll })
	W.list(Theme.Space.M).Parent = body

	local strip = W.new("Frame", {
		Name = "Rolls",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 54),
		LayoutOrder = 1,
		Parent = body,
	}, {
		W.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -8, 1, 0),
			CellPadding = UDim2.fromOffset(12, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local setters = {
		makeRoll(strip, "Material", 1),
		makeRoll(strip, "Quality", 2),
		makeRoll(strip, "Slots", 3),
	}
	W.divider({ LayoutOrder = 2, Parent = body })

	local headRow = W.new("Frame", { Name = "Rarity", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 3, Parent = body })
	local rarityLabel = W.caption("No sword yet", { Size = UDim2.new(0.6, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None, Parent = headRow })
	local oneInLabel = W.label({
		Text = "",
		Font = Theme.FontMono,
		TextSize = Theme.TextSize.Small,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = headRow,
	})
	local nameLabel = W.label({
		Name = "SwordName",
		Text = "YOUR FORGE IS READY",
		Font = Theme.FontDisplay,
		TextSize = Theme.TextSize.Name,
		TextColor3 = Theme.Muted,
		LayoutOrder = 4,
		Parent = body,
	})
	local details = W.new("Frame", {
		Name = "Details",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Parent = body,
	}, { W.list(Theme.Space.S) })
	W.label({
		Text = `Each forge rolls a material, a quality, and enchantment slots. It costs {Config.ForgeCost} gold.`,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Muted,
		Parent = details,
	})

	local function showCard(s)
		local rarity = Sword.rarity(s)
		local color = Theme.tierColor(rarity)
		setAccent(color)
		rarityLabel.Text = string.upper(Odds.tierName(rarity))
		rarityLabel.TextColor3 = color
		oneInLabel.Text = Odds.format(rarity)
		oneInLabel.TextColor3 = color
		nameLabel.Text = string.upper(Sword.name(s))
		nameLabel.TextColor3 = Theme.Text
		W.clear(details)
		ForgeTab.fillDetails(details, s, 0, false)
		W.pop(card, 0.95)
	end

	-- Row 3: the auto forge status. It shows what auto delete did and why a run stopped.
	local statusLabel = W.label({
		Name = "AutoStatus",
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Muted,
		LayoutOrder = 3,
		Visible = false,
		Parent = scroll,
	})
	local function showStatus(text: string)
		statusLabel.Text = text
		statusLabel.Visible = text ~= ""
	end

	local busy = false -- a forge animation plays
	local skip = false -- the player tapped to skip the animation
	local autoOn = false -- the Auto switch. Not saved: each visit starts with it off.
	local running = false -- an auto forge run goes
	local stopRequested = false

	-- Forges one sword and plays the reels. `speed` scales the reel stop times.
	-- Returns the result, or nil when the request fails.
	local function forgeOnce(speed: number): any?
		-- The server decides the result before the animation starts.
		local result = ctx.request("Forge")
		if not result.ok then
			return nil
		end
		W.sound("Forge")
		local s = result.sword
		local finals = {
			{ Sword.materialDef(s).name, s.odds.material },
			{ Sword.qualityDef(s).name, s.odds.quality },
			{ Odds.plural(s.slots, "slot"), s.odds.slots },
		}
		rarityLabel.Text = "FORGING"
		rarityLabel.TextColor3 = Theme.Faint
		oneInLabel.Text = ""
		local start = os.clock()
		local stopped = { false, false, false }
		local nextTick = 0
		local lastStop = -1
		while not (stopped[1] and stopped[2] and stopped[3]) do
			local t = os.clock() - start
			for i = 1, 3 do
				if not stopped[i] then
					if skip or t >= REEL_STOPS[i] * speed then
						stopped[i] = true
						setters[i](finals[i][1], Theme.tierColor(finals[i][2]), Odds.format(finals[i][2]))
						-- A skip stops all reels at the same time. Play one stop sound, not three.
						if t - lastStop > 0.05 then
							lastStop = t
							local rare = Odds.tier(finals[i][2]) >= 3
							W.sound("Stop", STOP_PITCH[i] * (if rare then 1.08 else 1))
						end
					else
						local m = Config.Materials[math.random(1, #Config.Materials)]
						setters[i](if i == 1 then m.name else "· · ·", Theme.Faint, "")
					end
				end
			end
			if not skip and t >= nextTick and not (stopped[1] and stopped[2] and stopped[3]) then
				nextTick = t + SPIN_TICK
				W.sound("Spin", 1.4)
			end
			task.wait(0.05)
		end
		showCard(s)
		local rarity = Sword.rarity(s)
		if rarity >= Config.RareFlashOneIn then
			Reveal.show(ctx, rarity, Sword.name(s)) -- The reveal plays its own sound.
		else
			W.sound("Result", Theme.ResultPitch[Odds.tier(rarity)])
		end
		return result
	end

	local function deletedText(result: any): string
		return `Auto deleted: {Sword.name(result.sword)} (+{W.number(result.autoDeleted.gold)} gold)`
	end

	-- Returns false and the reason when the next forge cannot work.
	local function canForge(): (boolean, string)
		local data = ctx.state.data
		if #data.swords >= Config.MaxSwords then
			return false, "Your sword list is full."
		end
		if data.gold < Config.ForgeCost then
			return false, "You do not have enough gold."
		end
		return true, ""
	end

	-- Forges again and again until a stop condition is true. See the auto forge design.
	local function runAuto()
		running = true
		stopRequested = false
		local forged, deleted, gold = 0, 0, 0
		local reason = "You stopped auto forge."
		local last = ""
		local function summary(): string
			local text = `Auto forge: {Odds.plural(forged, "sword")} forged`
			if deleted > 0 then
				text ..= `  ·  {deleted} auto deleted (+{W.number(gold)} gold)`
			end
			return text
		end
		showStatus("Auto forge started.")
		ctx.render()
		while true do
			if stopRequested then
				break
			end
			if ctx.currentTab ~= "Forge" or Sheet.isOpen() then
				reason = "Auto forge stopped because you left the Forge tab."
				break
			end
			local ok, why = canForge()
			if not ok then
				reason = why .. " Auto forge stopped."
				break
			end
			skip = false
			local result = forgeOnce(AUTO_SPEED)
			if not result then
				reason = "The forge did not work. Auto forge stopped."
				break
			end
			forged += 1
			if result.autoDeleted then
				deleted += 1
				gold += result.autoDeleted.gold
				last = deletedText(result) .. "\n"
			else
				last = ""
			end
			showStatus(last .. summary())
			local rarity = Sword.rarity(result.sword)
			if rarity >= Config.RareFlashOneIn then
				reason = "A very rare sword! Auto forge stopped."
				break
			end
			local rules = ctx.state.data.autoForge
			if rules and AutoDelete.reachesStop(rules, result.sword) then
				reason = `You got a {Odds.tierName(rarity)} sword. Auto forge stopped.`
				break
			end
			task.wait(AUTO_PAUSE)
		end
		running = false
		showStatus(last .. summary() .. "\n" .. reason)
		ctx.render()
	end

	-- The bottom row stays in the thumb zone: the Auto switch and the FORGE button.
	local forgeRow = W.new("Frame", {
		Name = "ForgeRow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -Theme.Space.M),
		Size = UDim2.new(1, 0, 0, Theme.PrimaryHeight),
		Parent = column,
	})
	local forgeButton
	local autoButton = W.button("Auto: off", {
		Name = "AutoButton",
		variant = "quiet",
		Size = UDim2.new(0, AUTO_WIDTH, 1, 0),
		TextSize = Theme.TextSize.Small,
		Parent = forgeRow,
	}, function()
		autoOn = not autoOn
		if not autoOn and running then
			stopRequested = true
		end
		ctx.render()
	end)
	forgeButton = W.button("FORGE", {
		Name = "ForgeButton",
		variant = "primary",
		Position = UDim2.fromOffset(AUTO_WIDTH + Theme.Space.S, 0),
		Size = UDim2.new(1, -(AUTO_WIDTH + Theme.Space.S), 1, 0),
		Font = Theme.FontDisplay,
		TextSize = Theme.TextSize.Title,
		Parent = forgeRow,
	}, function()
		if running then
			stopRequested = true
			skip = true -- also finish the current animation now
			return
		end
		if busy then
			skip = true -- A second tap skips the animation.
			return
		end
		busy = true
		skip = false
		if autoOn then
			runAuto()
		else
			forgeButton.Text = "TAP TO SKIP"
			local result = forgeOnce(1)
			showStatus(if result and result.autoDeleted then deletedText(result) else "")
		end
		busy = false
		ctx.render()
	end)
	ctx.targets.ForgeButton = forgeButton

	local function update(state)
		local data = state.data
		local full = #data.swords >= Config.MaxSwords
		local left = math.max(1, Config.PityLimit - data.pity)
		pityLabel.Text = `Steel or better within <b>{Odds.plural(left, "forge")}</b>  ·  {#data.swords}/{Config.MaxSwords} swords`
		autoButton.Text = if autoOn then "Auto: on" else "Auto: off"
		W.setVariant(autoButton, if autoOn then "secondary" else "quiet")
		if running then
			forgeButton.Text = "STOP"
			W.setEnabled(forgeButton, true)
			return
		end
		if busy then
			return
		end
		local label = if autoOn then "AUTO FORGE" else "FORGE"
		forgeButton.Text = if full then "SWORD LIST FULL" else `{label}  ·  {Config.ForgeCost} GOLD`
		W.setEnabled(forgeButton, not full and data.gold >= Config.ForgeCost)
	end

	return { update = update }
end

return ForgeTab
