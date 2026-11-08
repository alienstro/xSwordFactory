--!strict
-- The Fight tab: the monster list and the turn-based fight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Sword = require(Shared:WaitForChild("Sword")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

local FightTab = {}

local MAX_LOG = 60

function FightTab.create(page: Frame, ctx: any)
	local logLines: { string } = {}

	-- The monster list.
	local listPanel = W.panel({ Size = UDim2.fromScale(1, 1), Parent = page })
	local swordLabel = W.label({ Text = "", TextSize = 18, Parent = listPanel })
	local monsterScroll = W.scroll({ Size = UDim2.new(1, 0, 1, -40), Position = UDim2.new(0, 0, 0, 40), Parent = listPanel })
	W.list(6).Parent = monsterScroll

	-- The fight screen.
	local fightPanel = W.panel({ Size = UDim2.fromScale(1, 1), Visible = false, Parent = page })
	local monsterTitle = W.label({ Text = "", Font = Theme.FontBold, TextSize = 24, Parent = fightPanel })
	local _, setMonsterBar = W.bar(Theme.Bad, { Position = UDim2.new(0, 0, 0, 34), Parent = fightPanel })
	W.label({ Text = "You", Font = Theme.FontBold, Position = UDim2.new(0, 0, 0, 68), Parent = fightPanel })
	local _, setPlayerBar = W.bar(Theme.Good, { Position = UDim2.new(0, 0, 0, 94), Parent = fightPanel })

	local logScroll = W.scroll({
		Size = UDim2.new(1, 0, 1, -196),
		Position = UDim2.new(0, 0, 0, 130),
		Parent = fightPanel,
	})
	local logLabel = W.label({ Text = "", TextSize = 17, Parent = logScroll })

	local buttonRow = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 1, -56),
		Parent = fightPanel,
	}, {
		W.new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -6, 1, 0),
			CellPadding = UDim2.new(0, 8, 0, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local function addLog(lines: { string }?)
		for _, line in lines or {} do
			table.insert(logLines, line)
		end
		while #logLines > MAX_LOG do
			table.remove(logLines, 1)
		end
		logLabel.Text = table.concat(logLines, "\n")
		task.defer(function()
			logScroll.CanvasPosition = Vector2.new(0, math.max(0, logScroll.AbsoluteCanvasSize.Y - logScroll.AbsoluteSize.Y))
		end)
	end

	local function turn(action: string)
		return function()
			local result = ctx.request("FightTurn", { action = action })
			if result.ok then
				addLog(result.log)
				if result.outcome == "win" then
					ctx.toast(`You win! +{result.gold} gold`, Theme.GoldText)
				elseif result.outcome == "lose" then
					ctx.toast("You lose. You keep your sword.", Theme.Bad)
				end
			end
		end
	end

	local attackButton = W.button("Attack", { LayoutOrder = 1, BackgroundColor3 = Theme.Accent, TextColor3 = Theme.Background, Parent = buttonRow }, turn("Attack"))
	local defendButton = W.button("Defend", { LayoutOrder = 2, Parent = buttonRow }, turn("Defend"))
	local specialButton = W.button("Special", { LayoutOrder = 3, Parent = buttonRow }, turn("Special"))
	local fleeButton = W.button("Flee", { LayoutOrder = 4, Parent = buttonRow }, turn("Flee"))
	local backButton = W.button("Back to the monsters", {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 1, -56),
		BackgroundColor3 = Theme.Accent,
		TextColor3 = Theme.Background,
		Visible = false,
		Parent = fightPanel,
	}, function()
		ctx.request("LeaveFight")
	end)
	ctx.targets.AttackButton = attackButton

	local function startFight(index: number)
		local result = ctx.request("StartFight", { monsterIndex = index })
		if result.ok then
			table.clear(logLines)
			addLog(result.log)
		end
	end

	local function equipped(data)
		for _, s in data.swords do
			if s.id == data.equipped then
				return s
			end
		end
		return nil
	end

	local function updateList(data)
		local sword = equipped(data)
		if sword then
			local broken = if sword.durability <= 0 then ` <font color="{W.hex(Theme.Bad)}">Broken: repair it in the Swords tab.</font>` else ""
			swordLabel.Text = `Your sword: <b>{Sword.name(sword)}</b> · damage {math.floor(Sword.damage(sword) + 0.5)} · durability {sword.durability}/{sword.maxDurability}{broken}`
		else
			swordLabel.Text = `<font color="{W.hex(Theme.Bad)}">Equip a sword in the Swords tab first.</font>`
		end

		W.clear(monsterScroll)
		for i, m in Config.Monsters do
			local locked = i > data.unlocked
			local boss = if m.boss then " · BOSS" else ""
			local text = if locked
				then `🔒 {m.name}  (win against the {Config.Monsters[i - 1].name} first)`
				else `{m.name}{boss} · level {m.level} · {m.health} health · {W.number(m.gold)} gold`
			local b = W.button(text, {
				LayoutOrder = i,
				Size = UDim2.new(1, -8, 0, 50),
				TextSize = 18,
				BackgroundColor3 = if m.boss then Color3.fromRGB(90, 40, 40) else Theme.PanelLight,
				Parent = monsterScroll,
			}, function()
				startFight(i)
			end)
			b.TextXAlignment = Enum.TextXAlignment.Left
			W.padding(10).Parent = b
			W.setEnabled(b, not locked and sword ~= nil and sword.durability > 0)
			if i == 1 then
				ctx.targets.FirstMonster = b
			end
		end
	end

	local function updateFight(f)
		monsterTitle.Text = `{f.monsterName} · level {f.monsterLevel}`
		setMonsterBar(f.monsterHealth / f.monsterMaxHealth, `{f.monsterHealth}/{f.monsterMaxHealth}`)
		setPlayerBar(f.playerHealth / f.playerMaxHealth, `{f.playerHealth}/{f.playerMaxHealth}`)
		specialButton.Text = if f.cooldown > 0 then `Special ({f.cooldown})` else "Special"
		W.setEnabled(specialButton, f.cooldown <= 0)
		buttonRow.Visible = not f.over
		backButton.Visible = f.over
		for _, b in { attackButton, defendButton, fleeButton } do
			W.setEnabled(b, not f.over)
		end
	end

	local function update(state)
		local f = state.fight
		listPanel.Visible = f == nil
		fightPanel.Visible = f ~= nil
		if f then
			updateFight(f)
		else
			updateList(state.data)
		end
	end

	return { update = update }
end

return FightTab
