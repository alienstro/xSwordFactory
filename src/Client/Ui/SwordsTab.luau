--!strict
-- The Swords tab: a grid of sword cards. A tap opens a sheet with the actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Odds = require(Shared:WaitForChild("Odds")) :: any
local Sword = require(Shared:WaitForChild("Sword")) :: any
local Forge = require(Shared:WaitForChild("Forge")) :: any
local SwordFilter = require(Shared:WaitForChild("SwordFilter")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any
local Sheet = require(script.Parent.Sheet) :: any
local ForgeTab = require(script.Parent.ForgeTab) :: any
local SwordFilterSheet = require(script.Parent.SwordFilterSheet) :: any

local SwordsTab = {}

local function findSword(data, id: string?)
	for _, s in data.swords do
		if s.id == id then
			return s
		end
	end
	return nil
end

-- The sheet for one sword, with its details and all actions.
local function openSword(ctx: any, swordId: string)
	Sheet.open(ctx, "Sword", function(body, close)
		local function act(name: string)
			return function()
				local result = ctx.request(name, { swordId = swordId })
				if not result.ok then
					return
				end
				if name == "Enhance" then
					if result.success then
						W.sound("Success")
						ctx.toast("Enhance worked!", Theme.Good)
					else
						W.sound("Fail")
						ctx.toast("Enhance failed. The sword keeps its level.", Theme.Bad)
					end
				elseif name == "Enchant" and result.enchant then
					local e = result.enchant
					local def = Sword.enchantDef(e.id)
					ctx.toast(`New enchantment: {def.name} {Config.EnchantLevels[e.level].name}  ({Odds.format(e.oneIn)})`, Theme.tierColor(e.oneIn))
				elseif name == "Equip" then
					W.sound("Equip")
					ctx.toast("Sword equipped.", Theme.Good)
				elseif name == "Repair" then
					ctx.toast("Sword repaired.", Theme.Good)
				end
			end
		end

		return function(state)
			local data = state.data
			local s = findSword(data, swordId)
			if not s then
				close()
				return
			end
			W.clear(body)
			local rarity = Sword.rarity(s)
			local color = Theme.tierColor(rarity)
			local isEquipped = s.id == data.equipped

			W.chip(string.upper(Odds.tierName(rarity)) .. "  ·  " .. Odds.format(rarity) .. (if isEquipped then "  ·  EQUIPPED" else ""), color, { LayoutOrder = 1, Parent = body })
			W.label({ Text = string.upper(Sword.name(s)), Font = Theme.FontDisplay, TextSize = Theme.TextSize.Name, LayoutOrder = 2, Parent = body })
			W.divider({ LayoutOrder = 3, Parent = body })
			local order = ForgeTab.fillDetails(body, s, 3)

			local grid = W.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = order + 1,
				Parent = body,
			}, {
				W.new("UIGridLayout", {
					CellSize = UDim2.new(0.5, -4, 0, 52),
					CellPadding = UDim2.fromOffset(8, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			local function button(text: string, order_: number, enabled: boolean, onClick, props: { [string]: any }?)
				local p = props or {}
				p.LayoutOrder = order_
				p.TextSize = Theme.TextSize.Small
				p.TextWrapped = true
				p.Parent = grid
				local b = W.button(text, p, onClick)
				W.setEnabled(b, enabled)
				return b
			end

			ctx.targets.EquipButton =
				button(if isEquipped then "Equipped" else "Equip", 1, not isEquipped, act("Equip"), { variant = if isEquipped then "secondary" else "primary" })

			if s.enhance >= Config.MaxEnhance then
				ctx.targets.EnhanceButton = button("Enhance: max level", 2, false, act("Enhance"))
			else
				local to = s.enhance + 1
				local cost = Sword.enhanceCost(to)
				ctx.targets.EnhanceButton = button(
					`Enhance to +{to}\n{W.number(cost)} gold · {math.floor(Config.EnhanceChance[to] * 100)} %`,
					2,
					data.gold >= cost,
					act("Enhance")
				)
			end

			local available = Forge.enchantTable(data.upgrades, Forge.owned(s))
			if Sword.emptySlots(s) <= 0 then
				ctx.targets.EnchantButton = button("Enchant\nno empty slot", 3, false, act("Enchant"))
			elseif #available == 0 then
				ctx.targets.EnchantButton = button("Enchant\nnone left", 3, false, act("Enchant"))
			else
				local cost = Sword.enchantCost(s)
				ctx.targets.EnchantButton = button(`Enchant\n{W.number(cost)} gold`, 3, data.gold >= cost, act("Enchant"))
			end

			local repairCost = Sword.repairCost(s)
			button(
				if repairCost > 0 then `Repair\n{W.number(repairCost)} gold` else "Repair\nfull",
				4,
				repairCost > 0 and data.gold >= repairCost,
				act("Repair")
			)

			local value = Sword.salvageValue(s)
			local protected = isEquipped or s.favorite == true
			local salvageText = if isEquipped then "Salvage\nequipped" elseif s.favorite then "Salvage\nfavorite" else `Salvage\n+{W.number(value)} gold`
			button(salvageText, 5, not protected, function()
				Sheet.confirm(
					ctx,
					"Salvage this sword?",
					`<b>{Sword.name(s)}</b> ({Odds.format(rarity)}) breaks into <b>{W.number(value)} gold</b>. You cannot undo this.`,
					"Salvage",
					function()
						local result = ctx.request("Salvage", { swordId = swordId })
						if result.ok then
							W.sound("Salvage")
							ctx.toast(`You get {W.number(result.gold)} gold.`, Theme.Gold)
						end
					end
				)
			end, { variant = "danger" })

			button(if s.favorite then "Favorite\ntap to remove" else "Add to favorites\nprotects from salvage", 6, true, function()
				ctx.request("Favorite", { swordId = swordId })
			end)

			if Sword.emptySlots(s) > 0 and #available > 0 then
				local parts = {}
				for _, row in available do
					table.insert(parts, `{row.entry.name} {Odds.format(1 / row.p)}`)
				end
				W.label({
					Text = "Enchant odds for this sword: " .. table.concat(parts, "  ·  "),
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Muted,
					LayoutOrder = order + 2,
					Parent = body,
				})
			end
		end
	end)
end

function SwordsTab.create(page: Frame, ctx: any)
	local column = W.column(page)

	-- The header row: the count on the left, the two salvage actions on the right.
	local quickDelete = false
	-- The filter and the sort change only this view. They reset when the player joins again.
	local view = { filter = SwordFilter.new(), sort = "rarity" }
	local headerRow = W.new("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, Theme.Space.XS), Parent = column })
	local header = W.label({
		Name = "Count",
		Text = "",
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Muted,
		TextWrapped = false,
		Size = UDim2.new(1, -240, 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = headerRow,
	})
	local actions = W.new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = headerRow,
	}, { W.list(Theme.Space.S, true) })
	local quickButton
	quickButton = W.button("Quick delete", {
		Name = "QuickDelete",
		variant = "quiet",
		Size = UDim2.fromOffset(112, 36),
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 1,
		Parent = actions,
	}, function()
		quickDelete = not quickDelete
		W.setVariant(quickButton, if quickDelete then "danger" else "quiet")
		quickButton.Text = if quickDelete then "Quick delete on" else "Quick delete"
		if quickDelete then
			ctx.toast("Quick delete is on. Tap a sword to salvage it. Favorites stay.", Theme.Bad)
		end
		ctx.render()
	end)
	W.button("Salvage all", {
		Name = "SalvageAll",
		variant = "danger",
		Size = UDim2.fromOffset(112, 36),
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 2,
		Parent = actions,
	}, function()
		local data = ctx.state.data
		local count, gold = 0, 0
		for _, s in data.swords do
			if not s.favorite and s.id ~= data.equipped then
				count += 1
				gold += Sword.salvageValue(s)
			end
		end
		if count == 0 then
			ctx.toast("No sword to salvage. Favorites and the equipped sword stay.", Theme.Muted)
			return
		end
		-- Salvage all ignores the filter. Say so, because the player sees only the filtered list.
		local hidden = if SwordFilter.activeCount(view.filter) > 0 then " This includes the swords that the filter hides." else ""
		Sheet.confirm(
			ctx,
			"Salvage all?",
			`Salvage <b>{Odds.plural(count, "sword")}</b> for <b>{W.number(gold)} gold</b>. Your favorites and the equipped sword stay.{hidden} You cannot undo this.`,
			"Salvage all",
			function()
				local result = ctx.request("SalvageAll")
				if result.ok then
					W.sound("Salvage")
					ctx.toast(`Salvaged {Odds.plural(result.count, "sword")} for {W.number(result.gold)} gold.`, Theme.Gold)
				end
			end
		)
	end)

	-- The toolbar row: the Filter button, the Sort button, and a Clear button while a filter is active.
	local toolbar = W.new("Frame", {
		Name = "Toolbar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, Theme.Space.XS + 36 + Theme.Space.S),
		Parent = column,
	}, { W.list(Theme.Space.S, true) })
	local filterButton = W.button("Filter", {
		Name = "Filter",
		variant = "quiet",
		Size = UDim2.fromOffset(112, 36),
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 1,
		Parent = toolbar,
	}, function()
		SwordFilterSheet.open(ctx, view)
	end)
	local sortButton = W.button("", {
		Name = "Sort",
		variant = "quiet",
		Size = UDim2.fromOffset(140, 36),
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 2,
		Parent = toolbar,
	}, function()
		-- Each tap moves to the next sort.
		local i = table.find(SwordFilter.Sorts, view.sort) or 0
		view.sort = SwordFilter.Sorts[i % #SwordFilter.Sorts + 1]
		ctx.render()
	end)
	local clearButton = W.button("Clear", {
		Name = "ClearFilter",
		variant = "quiet",
		Size = UDim2.fromOffset(80, 36),
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 3,
		Parent = toolbar,
	}, function()
		view.filter = SwordFilter.new()
		ctx.render()
	end)

	local listTop = Theme.Space.XS + 2 * 36 + Theme.Space.S + Theme.Space.M
	local scroll = W.scroll({ Name = "List", Size = UDim2.new(1, 0, 1, -listTop), Position = UDim2.fromOffset(0, listTop), Parent = column })
	W.padding(0, 0).Parent = scroll
	W.list(Theme.Space.S).Parent = scroll
	local empty = W.label({
		Name = "Empty",
		Text = "You have no swords yet. Go to the Forge tab and tap FORGE.",
		TextColor3 = Theme.Muted,
		Position = UDim2.fromOffset(0, listTop + Theme.Space.L),
		Parent = column,
	})

	local function update(state)
		local data = state.data
		local active = SwordFilter.activeCount(view.filter)
		local list = SwordFilter.apply(data.swords, view.filter, view.sort, data.equipped)
		header.Text = if active > 0
			then `Showing <b>{#list}</b> of {#data.swords}  ·  {#data.swords}/{Config.MaxSwords}`
			else `<b>{#data.swords}</b> of {Config.MaxSwords} swords`
		filterButton.Text = if active > 0 then `Filter · {active}` else "Filter"
		W.setVariant(filterButton, if active > 0 then "secondary" else "quiet")
		sortButton.Text = `Sort: {SwordFilter.SortNames[view.sort]}`
		clearButton.Visible = active > 0
		empty.Visible = #list == 0
		empty.Text = if #data.swords == 0
			then "You have no swords yet. Go to the Forge tab and tap FORGE."
			else "No sword matches the filter. Tap Clear to see all your swords."
		W.clear(scroll)
		ctx.targets.FirstSword = nil
		for i, s in list do
			local rarity = Sword.rarity(s)
			local color = Theme.tierColor(rarity)
			local equipped = s.id == data.equipped
			local salvageMode = quickDelete and not s.favorite and not equipped
			local row = W.button("", {
				Name = "Sword" .. i,
				LayoutOrder = i,
				BackgroundColor3 = if equipped then Theme.Raised else Theme.Surface,
				Size = UDim2.new(1, 0, 0, 60),
				Parent = scroll,
			}, function()
				if not quickDelete then
					openSword(ctx, s.id)
					return
				end
				if s.favorite or equipped then
					ctx.toast("Favorites and the equipped sword stay.", Theme.Muted)
					return
				end
				local result = ctx.request("Salvage", { swordId = s.id })
				if result.ok then
					W.sound("Salvage")
					ctx.toast(`+{W.number(result.gold)} gold`, Theme.Gold)
				end
			end)
			row.ClipsDescendants = true
			W.new("Frame", { Name = "Stripe", Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = row })

			-- Left: the name, and under it the rarity and the odds.
			local left = W.new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(Theme.Space.L, 0),
				Size = UDim2.new(1, -(Theme.Space.L + 150), 1, 0),
				Parent = row,
			}, { W.list(2) })
			left.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			W.label({
				Text = string.upper(Sword.name(s)),
				Font = Theme.FontDisplay,
				TextSize = Theme.TextSize.Lead,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, 0, 0, 22),
				AutomaticSize = Enum.AutomaticSize.None,
				LayoutOrder = 1,
				Parent = left,
			})
			local tag = string.upper(Odds.tierName(rarity)) .. `  <font face="RobotoMono">{Odds.format(rarity)}</font>`
			if equipped then
				tag ..= `  ·  <font color="{W.hex(Theme.Text)}">EQUIPPED</font>`
			end
			if salvageMode then
				tag = `<font color="{W.hex(Theme.Bad)}">TAP TO SALVAGE  +{W.number(Sword.salvageValue(s))} GOLD</font>`
			end
			W.label({
				Text = tag,
				Font = Theme.FontBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = color,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, 0, 0, 16),
				AutomaticSize = Enum.AutomaticSize.None,
				LayoutOrder = 2,
				Parent = left,
			})

			-- Right: durability, then the favourite star.
			local broken = s.durability <= 0
			W.label({
				Text = if broken then "BROKEN" else `{s.durability}/{s.maxDurability}`,
				Font = if broken then Theme.FontBold else Theme.FontMono,
				TextSize = Theme.TextSize.Small,
				TextColor3 = if broken then Theme.Bad else Theme.Muted,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextYAlignment = Enum.TextYAlignment.Center,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -48, 0, 0),
				Size = UDim2.new(0, 90, 1, 0),
				AutomaticSize = Enum.AutomaticSize.None,
				Parent = row,
			})
			local star = W.button("⭐", {
				Name = "Favorite",
				variant = "quiet",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -Theme.Space.S, 0.5, 0),
				Size = UDim2.fromOffset(36, 36),
				TextSize = Theme.TextSize.Lead,
				Parent = row,
			}, function()
				ctx.request("Favorite", { swordId = s.id })
			end)
			star.TextTransparency = if s.favorite then 0 else 0.8
			if i == 1 then
				ctx.targets.FirstSword = row
			end
		end
	end

	return { update = update }
end

return SwordsTab
