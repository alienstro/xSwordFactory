--!strict
-- The Swords tab: the sword list and the actions for one sword.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Odds = require(Shared:WaitForChild("Odds")) :: any
local Sword = require(Shared:WaitForChild("Sword")) :: any
local Forge = require(Shared:WaitForChild("Forge")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any
local ForgeTab = require(script.Parent.ForgeTab) :: any

local SwordsTab = {}

function SwordsTab.create(page: Frame, ctx: any)
	local selectedId: string? = nil

	-- Left side: the list.
	local left = W.panel({ Size = UDim2.new(0.42, -6, 1, 0), Parent = page })
	local countLabel = W.label({ Text = "", Font = Theme.FontBold, TextSize = 22, Parent = left })
	local list = W.scroll({ Size = UDim2.new(1, 0, 1, -34), Position = UDim2.new(0, 0, 0, 34), Parent = left })
	W.list(6).Parent = list

	-- Right side: the details.
	local right = W.panel({
		Size = UDim2.new(0.58, -6, 1, 0),
		Position = UDim2.new(0.42, 6, 0, 0),
		Parent = page,
	})
	local detailScroll = W.scroll({ Size = UDim2.fromScale(1, 1), Parent = right })
	W.list(8).Parent = detailScroll
	local nameLabel = W.label({ Text = "Select a sword.", Font = Theme.FontBold, TextSize = 26, LayoutOrder = 1, Parent = detailScroll })
	local bodyLabel = W.label({ Text = "", TextSize = 17, LayoutOrder = 2, Parent = detailScroll })

	local grid = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		Parent = detailScroll,
	}, {
		W.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 48),
			CellPadding = UDim2.new(0, 8, 0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local enchantOddsLabel = W.label({ Text = "", TextSize = 15, TextColor3 = Theme.Muted, LayoutOrder = 4, Parent = detailScroll })

	local function act(name: string)
		return function()
			if not selectedId then
				return
			end
			local result = ctx.request(name, { swordId = selectedId })
			if not result.ok then
				return
			end
			if name == "Enhance" then
				if result.success then
					ctx.toast("Enhance worked!", Theme.Good)
				else
					ctx.toast("Enhance failed. The sword keeps its level.", Theme.Bad)
				end
			elseif name == "Enchant" and result.enchant then
				local e = result.enchant
				ctx.toast(`New enchantment: {Sword.enchantDef(e.id).name} {Config.EnchantLevels[e.level].name} ({Odds.format(e.oneIn)})`, Theme.tierColor(e.oneIn))
				if e.oneIn >= Config.RareFlashOneIn then
					ctx.flash(Theme.tierColor(e.oneIn))
				end
			elseif name == "Salvage" then
				ctx.toast(`You get {result.gold} gold.`, Theme.GoldText)
				selectedId = nil
				ctx.render()
			elseif name == "Equip" then
				ctx.toast("Sword equipped.", Theme.Good)
			elseif name == "Repair" then
				ctx.toast("Sword repaired.", Theme.Good)
			end
		end
	end

	local equipButton = W.button("Equip", { LayoutOrder = 1, Parent = grid }, act("Equip"))
	local enhanceButton = W.button("Enhance", { LayoutOrder = 2, Parent = grid }, act("Enhance"))
	local enchantButton = W.button("Enchant", { LayoutOrder = 3, Parent = grid }, act("Enchant"))
	local repairButton = W.button("Repair", { LayoutOrder = 4, Parent = grid }, act("Repair"))
	local salvageButton = W.button("Salvage", { LayoutOrder = 5, BackgroundColor3 = Color3.fromRGB(90, 50, 50), Parent = grid }, act("Salvage"))
	for _, b in { equipButton, enhanceButton, enchantButton, repairButton, salvageButton } do
		b.TextSize = 16
		b.TextWrapped = true
	end
	ctx.targets.EquipButton = equipButton
	ctx.targets.EnhanceButton = enhanceButton
	ctx.targets.EnchantButton = enchantButton

	local function sorted(swords)
		local copy = table.clone(swords)
		table.sort(copy, function(a, b)
			return Sword.rarity(a) > Sword.rarity(b)
		end)
		return copy
	end

	local function update(state)
		local data = state.data
		countLabel.Text = `Swords {#data.swords}/{Config.MaxSwords}`

		local selected = nil
		for _, s in data.swords do
			if s.id == selectedId then
				selected = s
			end
		end
		if not selected then
			selectedId = data.equipped
			for _, s in data.swords do
				if s.id == selectedId then
					selected = s
				end
			end
		end
		if not selected and #data.swords > 0 then
			selected = data.swords[#data.swords]
			selectedId = selected.id
		end

		W.clear(list)
		for i, s in sorted(data.swords) do
			local tag = if s.id == data.equipped then "  ⚔ Equipped" else ""
			local broken = if s.durability <= 0 then "  (broken)" else ""
			local b = W.button(`{Sword.name(s)}{tag}{broken}\n{Odds.format(Sword.rarity(s))}`, {
				LayoutOrder = i,
				Size = UDim2.new(1, -8, 0, 52),
				TextSize = 16,
				TextColor3 = Theme.tierColor(Sword.rarity(s)),
				BackgroundColor3 = if s.id == selectedId then Theme.ButtonHover else Theme.PanelLight,
				Parent = list,
			}, function()
				selectedId = s.id
				ctx.render()
			end)
			b.TextXAlignment = Enum.TextXAlignment.Left
			W.padding(8).Parent = b
		end
		if #data.swords == 0 then
			W.label({ Text = "You have no swords. Forge one first.", TextColor3 = Theme.Muted, Parent = list })
		end

		local controls = { equipButton, enhanceButton, enchantButton, repairButton, salvageButton }
		if not selected then
			nameLabel.Text = "Select a sword."
			nameLabel.TextColor3 = Theme.Text
			bodyLabel.Text = ""
			enchantOddsLabel.Text = ""
			for _, b in controls do
				W.setEnabled(b, false)
			end
			return
		end

		nameLabel.Text = Sword.name(selected)
		nameLabel.TextColor3 = Theme.tierColor(Sword.rarity(selected))
		bodyLabel.Text = table.concat(ForgeTab.describe(selected), "\n")

		local isEquipped = selected.id == data.equipped
		equipButton.Text = if isEquipped then "Equipped" else "Equip"
		W.setEnabled(equipButton, not isEquipped)

		if selected.enhance >= Config.MaxEnhance then
			enhanceButton.Text = "Enhance: max level"
			W.setEnabled(enhanceButton, false)
		else
			local to = selected.enhance + 1
			local cost = Sword.enhanceCost(to)
			enhanceButton.Text = `Enhance to +{to} · {W.number(cost)} gold · {math.floor(Config.EnhanceChance[to] * 100)} %`
			W.setEnabled(enhanceButton, data.gold >= cost)
		end

		local available = Forge.enchantTable(data.upgrades, Forge.owned(selected))
		if Sword.emptySlots(selected) <= 0 then
			enchantButton.Text = "Enchant: no empty slot"
			W.setEnabled(enchantButton, false)
		elseif #available == 0 then
			enchantButton.Text = "Enchant: none left"
			W.setEnabled(enchantButton, false)
		else
			local cost = Sword.enchantCost(selected)
			enchantButton.Text = `Enchant · {W.number(cost)} gold`
			W.setEnabled(enchantButton, data.gold >= cost)
		end

		local repairCost = Sword.repairCost(selected)
		repairButton.Text = if repairCost > 0 then `Repair · {W.number(repairCost)} gold` else "Repair: full"
		W.setEnabled(repairButton, repairCost > 0 and data.gold >= repairCost)

		salvageButton.Text = if isEquipped then "Salvage: equipped" else `Salvage · +{W.number(Sword.salvageValue(selected))} gold`
		W.setEnabled(salvageButton, not isEquipped)

		if Sword.emptySlots(selected) > 0 and #available > 0 then
			local parts = {}
			for _, row in available do
				table.insert(parts, `{row.entry.name} {Odds.format(1 / row.p)}`)
			end
			enchantOddsLabel.Text = "Enchant odds for this sword: " .. table.concat(parts, " · ")
		else
			enchantOddsLabel.Text = ""
		end
	end

	return { update = update }
end

return SwordsTab
