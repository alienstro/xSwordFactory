--!strict
-- The Swords tab: a grid of sword cards. A tap opens a sheet with the actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Odds = require(Shared:WaitForChild("Odds")) :: any
local Sword = require(Shared:WaitForChild("Sword")) :: any
local Forge = require(Shared:WaitForChild("Forge")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any
local Sheet = require(script.Parent.Sheet) :: any
local ForgeTab = require(script.Parent.ForgeTab) :: any

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
						W.sound("Win", 0.4)
						ctx.toast("Enhance worked!", Theme.Good)
					else
						ctx.toast("Enhance failed. The sword keeps its level.", Theme.Bad)
					end
				elseif name == "Enchant" and result.enchant then
					local e = result.enchant
					local def = Sword.enchantDef(e.id)
					ctx.toast(`New enchantment: {def.name} {Config.EnchantLevels[e.level].name}  ({Odds.format(e.oneIn)})`, Theme.tierColor(e.oneIn))
				elseif name == "Equip" then
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

			W.chip(string.upper(Odds.tierName(rarity)) .. (if isEquipped then "  ·  EQUIPPED" else ""), color, { LayoutOrder = 1, Parent = body })
			W.label({ Text = Sword.name(s), Font = Theme.FontDisplay, TextSize = 30, TextColor3 = color, LayoutOrder = 2, Parent = body })
			W.label({ Text = Odds.format(rarity), Font = Theme.FontDisplay, TextSize = 26, TextColor3 = color, LayoutOrder = 3, Parent = body })
			local order = ForgeTab.fillDetails(body, s, 3)

			local grid = W.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = order + 1,
				Parent = body,
			}, {
				W.new("UIGridLayout", {
					CellSize = UDim2.new(0.5, -5, 0, 54),
					CellPadding = UDim2.fromOffset(10, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			local function button(text: string, order_: number, enabled: boolean, onClick, props: { [string]: any }?)
				local p = props or {}
				p.LayoutOrder = order_
				p.TextSize = 16
				p.TextWrapped = true
				p.Parent = grid
				local b = W.button(text, p, onClick)
				W.setEnabled(b, enabled)
				return b
			end

			ctx.targets.EquipButton =
				button(if isEquipped then "Equipped" else "Equip", 1, not isEquipped, act("Equip"), { primary = not isEquipped })

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
							ctx.toast(`You get {W.number(result.gold)} gold.`, Theme.Gold)
						end
					end
				)
			end, { BackgroundColor3 = Color3.fromRGB(110, 40, 60) })

			button(if s.favorite then "⭐ Favorite\ntap to remove" else "Add to favorites\nprotects from salvage", 6, true, function()
				ctx.request("Favorite", { swordId = swordId })
			end)

			if Sword.emptySlots(s) > 0 and #available > 0 then
				local parts = {}
				for _, row in available do
					table.insert(parts, `{row.entry.name} {Odds.format(1 / row.p)}`)
				end
				W.label({
					Text = "Enchant odds for this sword: " .. table.concat(parts, "  ·  "),
					TextSize = 14,
					TextColor3 = Theme.Muted,
					LayoutOrder = order + 2,
					Parent = body,
				})
			end
		end
	end)
end

function SwordsTab.create(page: Frame, ctx: any)
	local column = W.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		Parent = page,
	}, { W.maxWidth(560) })

	local quickDelete = false
	local header = W.label({
		Text = "",
		Font = Theme.FontDisplay,
		TextSize = 22,
		TextWrapped = false,
		Size = UDim2.new(1, -250, 0, 40),
		Position = UDim2.fromOffset(0, 6),
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = column,
	})
	local quickButton
	quickButton = W.button("Quick delete", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -128, 0, 6),
		Size = UDim2.fromOffset(120, 40),
		TextSize = 15,
		Parent = column,
	}, function()
		quickDelete = not quickDelete
		W.setColor(quickButton, if quickDelete then Theme.Bad else Theme.Button)
		quickButton.Text = if quickDelete then "Quick delete: ON" else "Quick delete"
		if quickDelete then
			ctx.toast("Quick delete is on. Tap a sword to salvage it. Favorites stay.", Theme.Bad)
		end
		ctx.render()
	end)
	W.button("Salvage all", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 6),
		Size = UDim2.fromOffset(120, 40),
		TextSize = 15,
		BackgroundColor3 = Color3.fromRGB(110, 40, 60),
		Parent = column,
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
		Sheet.confirm(
			ctx,
			"Salvage all?",
			`Salvage <b>{Odds.plural(count, "sword")}</b> for <b>{W.number(gold)} gold</b>. Your favorites and the equipped sword stay. You cannot undo this.`,
			"Salvage all",
			function()
				local result = ctx.request("SalvageAll")
				if result.ok then
					ctx.toast(`Salvaged {Odds.plural(result.count, "sword")} for {W.number(result.gold)} gold.`, Theme.Gold)
				end
			end
		)
	end)

	local scroll = W.scroll({ Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 46), Parent = column })
	W.padding(4, 4).Parent = scroll
	W.new("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -8, 0, 112),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	local empty = W.label({
		Text = "You have no swords yet. Go to the Forge tab and tap FORGE.",
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 80),
		Parent = column,
	})

	local function sorted(data)
		local list = table.clone(data.swords)
		table.sort(list, function(a, b)
			if (a.id == data.equipped) ~= (b.id == data.equipped) then
				return a.id == data.equipped
			end
			return Sword.rarity(a) > Sword.rarity(b)
		end)
		return list
	end

	local function update(state)
		local data = state.data
		header.Text = `Your swords  {#data.swords}/{Config.MaxSwords}`
		empty.Visible = #data.swords == 0
		W.clear(scroll)
		ctx.targets.FirstSword = nil
		for i, s in sorted(data) do
			local rarity = Sword.rarity(s)
			local color = Theme.tierColor(rarity)
			local cardButton = W.button("", {
				LayoutOrder = i,
				BackgroundColor3 = Color3.new(1, 1, 1),
				Parent = scroll,
			}, function()
				if not quickDelete then
					openSword(ctx, s.id)
					return
				end
				if s.favorite or s.id == data.equipped then
					ctx.toast("Favorites and the equipped sword stay.", Theme.Muted)
					return
				end
				local result = ctx.request("Salvage", { swordId = s.id })
				if result.ok then
					ctx.toast(`+{W.number(result.gold)} gold`, Theme.Gold)
				end
			end)
			W.gradient(color:Lerp(Theme.PanelLight, 0.72), Theme.Panel, 90).Parent = cardButton
			W.stroke(color, if s.id == data.equipped then 3 else 1.5).Parent = cardButton
			W.padding(8).Parent = cardButton
			-- The text goes in a body frame, so that the star stays outside the list layout.
			local body = W.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = cardButton }, { W.list(3) })
			local tag = if s.id == data.equipped then "EQUIPPED" else string.upper(Odds.tierName(rarity))
			W.chip(tag, color, { TextSize = 11, Size = UDim2.new(0, 0, 0, 18), LayoutOrder = 1, Parent = body })
			W.label({
				Text = Sword.name(s),
				Font = Theme.FontDisplay,
				TextSize = 17,
				LayoutOrder = 2,
				Parent = body,
			})
			W.label({ Text = Odds.format(rarity), Font = Theme.FontBold, TextSize = 15, TextColor3 = color, LayoutOrder = 3, Parent = body })
			local broken = s.durability <= 0
			W.label({
				Text = if broken then "BROKEN" else `{s.durability}/{s.maxDurability} durability`,
				TextSize = 13,
				TextColor3 = if broken then Theme.Bad else Theme.Muted,
				LayoutOrder = 4,
				Parent = body,
			})
			local star = W.button("⭐", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 4, 0, -4),
				Size = UDim2.fromOffset(34, 34),
				TextSize = 20,
				BackgroundTransparency = 1,
				Parent = cardButton,
			}, function()
				ctx.request("Favorite", { swordId = s.id })
			end)
			star.TextTransparency = if s.favorite then 0 else 0.75
			if quickDelete and not s.favorite and s.id ~= data.equipped then
				W.label({
					Text = "TAP TO SALVAGE",
					Font = Theme.FontBold,
					TextSize = 12,
					TextColor3 = Theme.Bad,
					LayoutOrder = 5,
					Parent = body,
				})
			end
			if i == 1 then
				ctx.targets.FirstSword = cardButton
			end
		end
	end

	return { update = update }
end

return SwordsTab
