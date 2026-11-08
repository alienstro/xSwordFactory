--!strict
-- The Upgrades tab: forge upgrades that give better odds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

local UpgradesTab = {}

function UpgradesTab.create(page: Frame, ctx: any)
	local column = W.column(page)
	local scroll = W.scroll({ Name = "Body", Size = UDim2.fromScale(1, 1), Parent = column })
	W.list(Theme.Space.S).Parent = scroll
	W.padding(0, Theme.Space.XS).Parent = scroll

	W.label({
		Name = "Intro",
		Text = "Each level makes rare results more likely. <b>See odds</b> on the Forge tab always shows the real odds.",
		TextColor3 = Theme.Muted,
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 0,
		Parent = scroll,
	})

	local rows = {}
	for i, def in Config.Upgrades do
		local card = W.card({ Name = def.id, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i, Parent = scroll })
		local text = W.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -164, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = card,
		}, { W.list(Theme.Space.XS) })
		local title = W.label({
			Text = "",
			Font = Theme.FontDisplay,
			TextSize = Theme.TextSize.Lead,
			LayoutOrder = 1,
			Parent = text,
		})
		local info = W.label({
			Text = "",
			TextColor3 = Theme.Muted,
			TextSize = Theme.TextSize.Small,
			LayoutOrder = 2,
			Parent = text,
		})
		local _, setDots = W.dots({ LayoutOrder = 3, Parent = text }, def.maxLevel, Theme.Accent)
		local buy = W.button("Upgrade", {
			Name = "Buy",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(148, Theme.ControlHeight),
			TextSize = Theme.TextSize.Small,
			Parent = card,
		}, function()
			local result = ctx.request("Upgrade", { upgradeId = def.id })
			if result.ok then
				W.sound("Success")
				ctx.toast(`{def.name} upgraded.`, Theme.Good)
			end
		end)
		rows[def.id] = { def = def, title = title, info = info, setDots = setDots, buy = buy }
	end

	local function update(state)
		local data = state.data
		for _, row in rows do
			local def = row.def
			local level = data.upgrades[def.id] or 0
			row.title.Text = `{string.upper(def.name)}  <font face="RobotoMono" size="14" color="{W.hex(Theme.Faint)}">{level}/{def.maxLevel}</font>`
			row.setDots(level)
			local now = def.mult(level)
			if level >= def.maxLevel then
				row.info.Text = `{def.text}. Rare chances ×{now}.`
				row.buy.Text = "Max level"
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
