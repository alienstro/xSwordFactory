--!strict
-- The Upgrades tab: forge upgrades that give better odds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

local UpgradesTab = {}

local ICONS = { Luck = "🍀", Slots = "💎", Durability = "🛡️" }
local COLORS = { Luck = Theme.Tiers[2], Slots = Theme.Tiers[4], Durability = Theme.Tiers[3] }

function UpgradesTab.create(page: Frame, ctx: any)
	local column = W.scroll({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, -28, 1, 0),
		Parent = page,
	})
	W.maxWidth(560).Parent = column
	W.list(12).Parent = column
	W.padding(4, 8).Parent = column

	W.label({ Text = "Forge upgrades", Font = Theme.FontDisplay, TextSize = 24, LayoutOrder = 0, Parent = column })
	W.label({
		Text = "Each level makes the rare results more likely. The Odds sheet in the Forge tab always shows the real odds.",
		TextColor3 = Theme.Muted,
		TextSize = 16,
		LayoutOrder = 1,
		Parent = column,
	})

	local rows = {}
	for i, def in Config.Upgrades do
		local color = COLORS[def.id] or Theme.Gold
		local card = W.card({ Size = UDim2.new(1, 0, 0, 128), LayoutOrder = 1 + i, Parent = column })
		W.stroke(color, 1.5, 0.4).Parent = card
		W.label({
			Text = ICONS[def.id] or "⭐",
			TextSize = 34,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(48, 48),
			Parent = card,
		})
		local title = W.label({
			Text = "",
			Font = Theme.FontDisplay,
			TextSize = 21,
			Size = UDim2.new(1, -60, 0, 26),
			Position = UDim2.fromOffset(58, 0),
			Parent = card,
		})
		local info = W.label({
			Text = "",
			TextColor3 = Theme.Muted,
			TextSize = 15,
			Size = UDim2.new(1, -60, 0, 20),
			Position = UDim2.fromOffset(58, 28),
			Parent = card,
		})
		local _, setDots = W.dots({ Position = UDim2.fromOffset(58, 56), Parent = card }, def.maxLevel, color)
		local buy = W.button("Buy", {
			primary = true,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 42),
			TextSize = 17,
			Parent = card,
		}, function()
			local result = ctx.request("Upgrade", { upgradeId = def.id })
			if result.ok then
				W.sound("Win", 0.4)
				ctx.toast(`{def.name} upgraded!`, Theme.Good)
			end
		end)
		rows[def.id] = { def = def, title = title, info = info, setDots = setDots, buy = buy }
	end

	local function update(state)
		local data = state.data
		for _, row in rows do
			local def = row.def
			local level = data.upgrades[def.id] or 0
			row.title.Text = `{def.name}  <font color="{W.hex(Theme.Muted)}">level {level}/{def.maxLevel}</font>`
			row.setDots(level)
			local now = def.mult(level)
			if level >= def.maxLevel then
				row.info.Text = `{def.text}. Rare chances ×{now}.`
				row.buy.Text = "MAX LEVEL"
				W.setEnabled(row.buy, false)
			else
				local cost = def.cost(level)
				row.info.Text = `{def.text}. Rare chances ×{now} → ×{def.mult(level + 1)}`
				row.buy.Text = `Upgrade  ·  {W.number(cost)} gold`
				W.setEnabled(row.buy, data.gold >= cost)
			end
		end
	end

	return { update = update }
end

return UpgradesTab
