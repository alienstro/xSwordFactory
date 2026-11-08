--!strict
-- The Fight tab: the monster list and the turn-based fight, with an AUTO mode.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Odds = require(Shared:WaitForChild("Odds")) :: any
local Sword = require(Shared:WaitForChild("Sword")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

local FightTab = {}

local LOG_LINES = 3
local AUTO_TURN_DELAY = 0.45 -- Seconds between two AUTO turns.
local AUTO_RESTART_DELAY = 0.9 -- Seconds before AUTO starts the next fight.

local function equipped(data)
	for _, s in data.swords do
		if s.id == data.equipped then
			return s
		end
	end
	return nil
end

-- A flat tile with the monster emoji.
local function portrait(parent: Instance, monster, size: number, props: { [string]: any }?): Frame
	local p = props or {}
	p.Name = p.Name or "Portrait"
	p.Size = UDim2.fromOffset(size, size)
	p.BackgroundColor3 = if monster.boss then Theme.DangerSurface else Theme.Raised
	p.BorderSizePixel = 0
	p.Parent = parent
	local frame = W.new("Frame", p, { W.corner(Theme.Radius.Control) })
	W.label({
		Text = monster.icon or "?",
		TextSize = math.floor(size * 0.55),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	})
	return frame
end

-- A number that floats up from an object and fades out.
local function floatText(parent: GuiObject, text: string, color: Color3)
	local label = W.label({
		Text = text,
		Font = Theme.FontMono,
		TextSize = Theme.TextSize.Title,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.4, 0.4),
		Size = UDim2.fromOffset(140, 36),
		ZIndex = 20,
		Parent = parent,
	})
	W.tween(label, 0.8, { Position = label.Position - UDim2.fromOffset(0, 32), TextTransparency = 1 })
	task.delay(0.85, function()
		label:Destroy()
	end)
end

function FightTab.create(page: Frame, ctx: any)
	local column = W.column(page)

	---------------------------------------------------------------- The monster list.
	local listView = W.scroll({ Name = "Monsters", Size = UDim2.fromScale(1, 1), Parent = column })
	W.list(Theme.Space.M).Parent = listView
	W.padding(0, Theme.Space.XS).Parent = listView
	local _, swordBody, setSwordAccent = W.accentCard({ Name = "Equipped", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = listView })
	W.list(Theme.Space.XS).Parent = swordBody
	local swordCaption = W.caption("Equipped sword", { LayoutOrder = 1, Parent = swordBody })
	local swordLabel = W.label({ Text = "", Font = Theme.FontDisplay, TextSize = Theme.TextSize.Lead, LayoutOrder = 2, Parent = swordBody })
	local swordStats = W.label({ Text = "", Font = Theme.FontMono, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Muted, LayoutOrder = 3, Parent = swordBody })
	local monsterScroll = W.new("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = listView,
	}, { W.list(Theme.Space.S) })

	---------------------------------------------------------------- The fight view.
	local fightView = W.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = column })
	local stage = W.card({ Name = "Stage", Position = UDim2.fromOffset(0, Theme.Space.XS), Parent = fightView })
	W.list(Theme.Space.S, false, Enum.HorizontalAlignment.Center).Parent = stage
	local portraitHolder = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 80),
		LayoutOrder = 1,
		Parent = stage,
	})
	local monsterName = W.label({
		Text = "",
		Font = Theme.FontDisplay,
		TextSize = Theme.TextSize.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = stage,
	})
	local _, setMonsterBar = W.bar(Theme.Bad, { LayoutOrder = 3, Parent = stage })
	W.divider({ LayoutOrder = 4, Parent = stage })
	local youLabel = W.label({ Text = "You", Font = Theme.FontMedium, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 5, Parent = stage })
	local playerBar, setPlayerBar = W.bar(Theme.Good, { LayoutOrder = 6, Parent = stage })
	local logLabel = W.label({ Name = "Log", Text = "", Font = Theme.FontMono, TextSize = 13, TextColor3 = Theme.Muted, LayoutOrder = 7, Parent = stage })

	local controls = W.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -10),
		Size = UDim2.new(1, 0, 0, 120),
		Parent = fightView,
	})
	local autoButton = W.button("Auto: off", { Name = "Auto", variant = "quiet", Size = UDim2.new(1, 0, 0, 44), TextSize = Theme.TextSize.Small, Parent = controls }, function() end)
	local actionRow = W.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 64),
		Parent = controls,
	}, {
		W.new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -6, 1, 0),
			CellPadding = UDim2.fromOffset(8, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local endRow = W.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 64),
		Visible = false,
		Parent = controls,
	}, {
		W.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -5, 1, 0),
			CellPadding = UDim2.fromOffset(10, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local resultBanner = W.label({
		Name = "Result",
		Text = "",
		Font = Theme.FontDisplay,
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Raised,
		Visible = false,
		ZIndex = 30,
		Parent = fightView,
	})
	W.corner(Theme.Radius.Surface).Parent = resultBanner
	W.padding(Theme.Space.XL, Theme.Space.M).Parent = resultBanner

	---------------------------------------------------------------- Fight logic on the client.
	local logLines: { string } = {}
	local auto = false
	local autoRunning = false
	local lastMonster = 1
	local monsterPortrait: Frame? = nil

	local function addLog(lines: { string }?)
		for _, line in lines or {} do
			table.insert(logLines, line)
		end
		while #logLines > LOG_LINES do
			table.remove(logLines, 1)
		end
		logLabel.Text = table.concat(logLines, "\n")
	end

	local function setAuto(on: boolean)
		auto = on
		autoButton.Text = if on then "Auto: on  ·  tap to stop" else "Auto: off"
		W.setVariant(autoButton, if on then "secondary" else "quiet")
		autoButton:SetAttribute("TextColor", if on then Theme.Good else nil)
		W.setEnabled(autoButton, true)
	end

	local function startFight(index: number): boolean
		local result = ctx.request("StartFight", { monsterIndex = index })
		if result.ok then
			lastMonster = index
			table.clear(logLines)
			addLog(result.log)
			resultBanner.Visible = false
		end
		return result.ok
	end

	-- Sends one turn and shows the damage that it did.
	local function turn(action: string)
		local before = ctx.state and ctx.state.fight
		local monsterBefore = if before then before.monsterHealth else 0
		local playerBefore = if before then before.playerHealth else 0
		local result = ctx.request("FightTurn", { action = action })
		if not result.ok then
			return result
		end
		addLog(result.log)
		local after = ctx.state.fight
		if after then
			local dealt = monsterBefore - after.monsterHealth
			local taken = playerBefore - after.playerHealth
			if dealt > 0 and monsterPortrait then
				floatText(monsterPortrait, `-{dealt}`, Theme.Gold)
				W.shake(monsterPortrait, 6, 0.2)
				W.sound("Hit")
			end
			if taken > 0 then
				floatText(playerBar, `-{taken}`, Theme.Bad)
			elseif taken < 0 then
				floatText(playerBar, `+{-taken}`, Theme.Good)
			end
		end
		if result.outcome == "win" then
			resultBanner.Text = `VICTORY  <font face="RobotoMono" size="20" color="{W.hex(Theme.Gold)}">+{W.number(result.gold)} gold</font>`
			resultBanner.TextColor3 = Theme.Text
			resultBanner.Visible = true
			W.pop(resultBanner, 0.9)
			W.sound("Win")
		elseif result.outcome == "lose" then
			resultBanner.Text = "DEFEAT"
			resultBanner.TextColor3 = Theme.Bad
			resultBanner.Visible = true
			W.pop(resultBanner, 0.9)
			W.sound("Lose")
		elseif result.outcome == "fled" then
			resultBanner.Visible = false
		end
		return result
	end

	-- AUTO: attack, use Special when it is ready, and start the next fight after a win.
	local function runAuto()
		if autoRunning then
			return
		end
		autoRunning = true
		while auto do
			local state = ctx.state
			local f = state and state.fight
			if f and not f.over then
				local result = turn(if f.cooldown <= 0 then "Special" else "Attack")
				if not result.ok then
					setAuto(false)
				end
				task.wait(AUTO_TURN_DELAY)
			elseif f and f.over then
				local won = f.monsterHealth <= 0
				local sword = equipped(state.data)
				if not won then
					ctx.toast("AUTO stops: you lost the fight.", Theme.Bad)
					setAuto(false)
				elseif not sword or sword.durability <= 0 then
					ctx.toast("AUTO stops: your sword is broken. Repair it.", Theme.Bad)
					setAuto(false)
				else
					task.wait(AUTO_RESTART_DELAY)
					if auto then
						ctx.request("LeaveFight")
						if not startFight(lastMonster) then
							setAuto(false)
						end
					end
				end
			else
				setAuto(false)
			end
		end
		autoRunning = false
		ctx.render()
	end

	autoButton.Activated:Connect(function()
		setAuto(not auto)
		if auto then
			task.spawn(runAuto)
		end
	end)

	local function actionButton(text: string, order: number, action: string, primary: boolean?): TextButton
		return W.button(text, { Name = action, LayoutOrder = order, variant = if primary then "primary" else "secondary", TextSize = Theme.TextSize.Body, Parent = actionRow }, function()
			if auto then
				setAuto(false)
			end
			turn(action)
		end)
	end
	local attackButton = actionButton("Attack", 1, "Attack", true)
	local defendButton = actionButton("Defend", 2, "Defend")
	local specialButton = actionButton("Special", 3, "Special")
	local fleeButton = actionButton("Flee", 4, "Flee")
	ctx.targets.AttackButton = attackButton
	ctx.targets.AutoButton = autoButton

	W.button("Fight again", { LayoutOrder = 1, variant = "primary", Parent = endRow }, function()
		ctx.request("LeaveFight")
		startFight(lastMonster)
	end)
	W.button("Back", { LayoutOrder = 2, Parent = endRow }, function()
		setAuto(false)
		resultBanner.Visible = false
		ctx.request("LeaveFight")
	end)

	---------------------------------------------------------------- Drawing.
	local shownMonster = 0

	local function updateList(data)
		local sword = equipped(data)
		if sword then
			local rarity = Sword.rarity(sword)
			local color = Theme.tierColor(rarity)
			setSwordAccent(color)
			swordCaption.Text = "EQUIPPED SWORD"
			swordLabel.Text = string.upper(Sword.name(sword))
			swordLabel.TextColor3 = Theme.Text
			local broken = if sword.durability <= 0 then `  ·  <font color="{W.hex(Theme.Bad)}">BROKEN, REPAIR IT</font>` else ""
			swordStats.Text = `{Odds.format(rarity)}  ·  DMG {math.floor(Sword.damage(sword) + 0.5)}  ·  DUR {sword.durability}/{sword.maxDurability}{broken}`
			swordStats.Font = Theme.FontMono -- numbers line up in the mono font
			swordStats.Visible = true
		else
			setSwordAccent(Theme.Bad)
			swordCaption.Text = "NO SWORD EQUIPPED"
			swordLabel.Text = "EQUIP A SWORD FIRST"
			swordLabel.TextColor3 = Theme.Muted
			swordStats.Text = "Open the Swords tab, tap a sword, then tap Equip."
			swordStats.Font = Theme.Font -- a sentence reads better in the body font
			swordStats.Visible = true
		end

		W.clear(monsterScroll)
		ctx.targets.FirstMonster = nil
		for i, m in Config.Monsters do
			local locked = i > data.unlocked
			local card = W.new("Frame", {
				Name = m.name,
				BackgroundColor3 = Theme.Surface,
				BackgroundTransparency = if locked then 0.5 else 0,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, if locked then 56 else 68),
				LayoutOrder = i,
				Parent = monsterScroll,
			}, { W.corner(Theme.Radius.Surface), W.padding(Theme.Space.M) })
			local tileSize = if locked then 32 else 44
			local tile = portrait(card, m, tileSize, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5) })
			if locked then
				tile.BackgroundTransparency = 0.5
				local glyph = tile:FindFirstChildOfClass("TextLabel") :: TextLabel
				glyph.TextTransparency = 0.6
			end
			local textBox = W.new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(tileSize + Theme.Space.M, 0),
				Size = UDim2.new(1, -(tileSize + Theme.Space.M + 120), 1, 0),
				Parent = card,
			}, { W.list(2) })
			textBox.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			W.label({
				Text = string.upper(m.name) .. (if m.boss and not locked then `  <font face="BuilderSans" weight="bold" size="12" color="{W.hex(Theme.Bad)}">BOSS</font>` else ""),
				Font = Theme.FontDisplay,
				TextSize = if locked then Theme.TextSize.Body else Theme.TextSize.Lead,
				TextColor3 = if locked then Theme.Faint else Theme.Text,
				Size = UDim2.new(1, 0, 0, 22),
				AutomaticSize = Enum.AutomaticSize.None,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = false,
				LayoutOrder = 1,
				Parent = textBox,
			})
			W.label({
				Text = if locked
					then `Locked. Win against the {Config.Monsters[i - 1].name} first.`
					else `LV {m.level}  ·  {m.health} HP  ·  <font color="{W.hex(Theme.Gold)}">{W.number(m.gold)} GOLD</font>`,
				Font = if locked then Theme.Font else Theme.FontMono,
				TextSize = if locked then Theme.TextSize.Small else 13,
				TextColor3 = if locked then Theme.Faint else Theme.Muted,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, 0, 0, 18),
				AutomaticSize = Enum.AutomaticSize.None,
				LayoutOrder = 2,
				Parent = textBox,
			})
			if not locked then
				local fight = W.button("Fight", {
					Name = "Fight",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(96, 40),
					TextSize = Theme.TextSize.Body,
					Parent = card,
				}, function()
					startFight(i)
				end)
				W.setEnabled(fight, sword ~= nil and sword.durability > 0)
				if i == 1 then
					ctx.targets.FirstMonster = fight
				end
			end
		end
	end

	local function updateFight(f, data)
		if shownMonster ~= f.monsterIndex or not monsterPortrait or not monsterPortrait.Parent then
			shownMonster = f.monsterIndex
			W.clear(portraitHolder)
			monsterPortrait = portrait(portraitHolder, Config.Monsters[f.monsterIndex], 80, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
			})
		end
		monsterName.Text = `{string.upper(f.monsterName)}  <font face="RobotoMono" size="14" color="{W.hex(Theme.Faint)}">LV {f.monsterLevel}</font>`
		setMonsterBar(f.monsterHealth / f.monsterMaxHealth, `{f.monsterHealth}/{f.monsterMaxHealth}`)
		setPlayerBar(f.playerHealth / f.playerMaxHealth, `{f.playerHealth}/{f.playerMaxHealth}`)
		local sword = equipped(data)
		youLabel.Text = if sword
			then `You  ·  <font color="{W.hex(Theme.tierColor(Sword.rarity(sword)))}">{Sword.name(sword)}</font>  ·  {Odds.format(Sword.rarity(sword))}`
			else "You"
		specialButton.Text = if f.cooldown > 0 then `Special ({f.cooldown})` else "Special"
		W.setEnabled(specialButton, f.cooldown <= 0)
		actionRow.Visible = not f.over
		endRow.Visible = f.over and not auto
		for _, b in { attackButton, defendButton, fleeButton } do
			W.setEnabled(b, not f.over)
		end
	end

	local function update(state)
		local f = state.fight
		listView.Visible = f == nil
		fightView.Visible = f ~= nil
		if f then
			updateFight(f, state.data)
		else
			resultBanner.Visible = false
			updateList(state.data)
		end
	end

	return { update = update }
end

return FightTab
