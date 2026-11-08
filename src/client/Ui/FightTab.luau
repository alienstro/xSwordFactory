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

-- A round portrait with the monster emoji.
local function portrait(parent: Instance, monster, size: number, props: { [string]: any }?): Frame
	local p = props or {}
	p.Size = UDim2.fromOffset(size, size)
	p.BackgroundColor3 = if monster.boss then Color3.fromRGB(110, 30, 50) else Theme.PanelLight
	p.BorderSizePixel = 0
	p.Parent = parent
	local frame = W.new("Frame", p, {
		W.corner(size // 2),
		W.stroke(if monster.boss then Theme.Bad else Theme.Button, 3),
	})
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
		Font = Theme.FontDisplay,
		TextSize = 30,
		TextColor3 = color,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.4, 0.4),
		Size = UDim2.fromOffset(140, 36),
		ZIndex = 20,
		Parent = parent,
	})
	W.tween(label, 0.8, { Position = label.Position - UDim2.fromOffset(0, 50), TextTransparency = 1, TextStrokeTransparency = 1 })
	task.delay(0.85, function()
		label:Destroy()
	end)
end

function FightTab.create(page: Frame, ctx: any)
	local column = W.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		Parent = page,
	}, { W.maxWidth(560) })

	---------------------------------------------------------------- The monster list.
	local listView = W.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = column })
	local swordCard = W.card({ Position = UDim2.fromOffset(0, 6), Parent = listView })
	local swordLabel = W.label({ Text = "", TextSize = 17, Parent = swordCard })
	local monsterScroll = W.scroll({ Size = UDim2.new(1, 0, 1, -86), Position = UDim2.fromOffset(0, 86), Parent = listView })
	W.list(10).Parent = monsterScroll
	W.padding(2, 4).Parent = monsterScroll

	---------------------------------------------------------------- The fight view.
	local fightView = W.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = column })
	local stage = W.card({ Position = UDim2.fromOffset(0, 6), Parent = fightView })
	W.list(8, false, Enum.HorizontalAlignment.Center).Parent = stage
	local portraitHolder = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 96),
		LayoutOrder = 1,
		Parent = stage,
	})
	local monsterName = W.label({
		Text = "",
		Font = Theme.FontDisplay,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = stage,
	})
	local _, setMonsterBar = W.bar(Theme.Bad, { LayoutOrder = 3, Parent = stage })
	W.label({ Text = "VS", Font = Theme.FontDisplay, TextSize = 18, TextColor3 = Theme.Muted, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 4, Parent = stage })
	local youLabel = W.label({ Text = "You", Font = Theme.FontBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 5, Parent = stage })
	local playerBar, setPlayerBar = W.bar(Theme.Good, { LayoutOrder = 6, Parent = stage })
	local logLabel = W.label({ Text = "", TextSize = 16, TextColor3 = Theme.Muted, LayoutOrder = 7, Parent = stage })

	local controls = W.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -10),
		Size = UDim2.new(1, 0, 0, 120),
		Parent = fightView,
	})
	local autoButton = W.button("AUTO: OFF", { Size = UDim2.new(1, 0, 0, 44), TextSize = 17, Parent = controls }, function() end)
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
		Text = "",
		Font = Theme.FontDisplay,
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Visible = false,
		ZIndex = 30,
		Parent = fightView,
	})

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
		autoButton.Text = if on then "AUTO: ON  ·  tap to stop" else "AUTO: OFF"
		W.setColor(autoButton, if on then Theme.Good else Theme.Button)
		autoButton.TextColor3 = if on then Theme.Background else Theme.Text
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
				W.sound("Hit", 0.4)
			end
			if taken > 0 then
				floatText(playerBar, `-{taken}`, Theme.Bad)
			elseif taken < 0 then
				floatText(playerBar, `+{-taken}`, Theme.Good)
			end
		end
		if result.outcome == "win" then
			resultBanner.Text = `VICTORY!  +{W.number(result.gold)} gold`
			resultBanner.TextColor3 = Theme.Gold
			resultBanner.Visible = true
			W.pop(resultBanner, 0.5)
			W.sound("Win", 0.5)
		elseif result.outcome == "lose" then
			resultBanner.Text = "DEFEAT"
			resultBanner.TextColor3 = Theme.Bad
			resultBanner.Visible = true
			W.pop(resultBanner, 0.5)
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
		return W.button(text, { LayoutOrder = order, primary = primary, TextSize = 17, Parent = actionRow }, function()
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

	W.button("Fight again", { LayoutOrder = 1, primary = true, Parent = endRow }, function()
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
			local broken = if sword.durability <= 0
				then `\n<font color="{W.hex(Theme.Bad)}">Your sword is broken. Repair it in the Swords tab.</font>`
				else ""
			swordLabel.Text = `Your sword: <b><font color="{W.hex(Theme.tierColor(rarity))}">{Sword.name(sword)}</font></b>\nDamage {math.floor(Sword.damage(sword) + 0.5)}  ·  Durability {sword.durability}/{sword.maxDurability}{broken}`
		else
			swordLabel.Text = `<font color="{W.hex(Theme.Bad)}">Equip a sword in the Swords tab first.</font>`
		end

		W.clear(monsterScroll)
		ctx.targets.FirstMonster = nil
		for i, m in Config.Monsters do
			local locked = i > data.unlocked
			local card = W.card({ Size = UDim2.new(1, 0, 0, 84), LayoutOrder = i, Parent = monsterScroll })
			if m.boss then
				W.stroke(Theme.Bad, 2).Parent = card
			end
			portrait(card, m, 56, { Position = UDim2.fromOffset(0, 0) })
			W.label({
				Text = if locked then `🔒 {m.name}` else `{m.name}{if m.boss then "  ·  BOSS" else ""}`,
				Font = Theme.FontDisplay,
				TextSize = 19,
				TextColor3 = if locked then Theme.Muted else Theme.Text,
				Size = UDim2.new(1, -190, 0, 26),
				Position = UDim2.fromOffset(68, 2),
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = false,
				Parent = card,
			})
			W.label({
				Text = if locked
					then `Win against the {Config.Monsters[i - 1].name} first.`
					else `Level {m.level}  ·  {m.health} health  ·  {W.number(m.gold)} gold`,
				TextSize = 14,
				TextColor3 = Theme.Muted,
				Size = UDim2.new(1, -190, 0, 20),
				Position = UDim2.fromOffset(68, 30),
				Parent = card,
			})
			if not locked then
				local fight = W.button("FIGHT", {
					primary = true,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(108, 48),
					Font = Theme.FontDisplay,
					TextSize = 20,
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
			monsterPortrait = portrait(portraitHolder, Config.Monsters[f.monsterIndex], 96, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
			})
		end
		monsterName.Text = `{f.monsterName}  <font color="{W.hex(Theme.Muted)}">level {f.monsterLevel}</font>`
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
