--!strict
-- The Upgrades tab: forge upgrades that give better odds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

local UpgradesTab = {}

function UpgradesTab.create(page: Frame, ctx: any)
	local panel = W.panel({ Size = UDim2.fromScale(1, 1), Parent = page })
	W.list(10).Parent = panel
	W.label({ Text = "Forge upgrades", Font = Theme.FontBold, TextSize = 24, LayoutOrder = 0, Parent = panel })
	W.label({
		Text = "Each level makes the rare entries more likely. The Forge tab always shows the real odds.",
		TextColor3 = Theme.Muted,
		LayoutOrder = 1,
		Parent = panel,
	})

	local rows = {}
	for i, def in Config.Upgrades do
		local row = W.panel({
			BackgroundColor3 = Theme.PanelLight,
			Size = UDim2.new(1, 0, 0, 84),
			LayoutOrder = 1 + i,
			Parent = panel,
		})
		local title = W.label({ Text = "", Font = Theme.FontBold, TextSize = 21, Size = UDim2.new(0.65, 0, 0, 28), Parent = row })
		local info = W.label({
			Text = "",
			TextColor3 = Theme.Muted,
			TextSize = 16,
			Size = UDim2.new(0.65, 0, 0, 30),
			Position = UDim2.new(0, 0, 0, 30),
			Parent = row,
		})
		local buy = W.button("Buy", {
			Size = UDim2.new(0.33, 0, 1, 0),
			Position = UDim2.new(0.67, 0, 0, 0),
			BackgroundColor3 = Theme.Accent,
			TextColor3 = Theme.Background,
			Parent = row,
		}, function()
			local result = ctx.request("Upgrade", { upgradeId = def.id })
			if result.ok then
				ctx.toast(`{def.name} upgraded.`, Theme.Good)
			end
		end)
		rows[def.id] = { def = def, title = title, info = info, buy = buy }
	end

	local function update(state)
		local data = state.data
		for _, row in rows do
			local def = row.def
			local level = data.upgrades[def.id] or 0
			row.title.Text = `{def.name} · level {level}/{def.maxLevel}`
			local now = def.mult(level)
			if level >= def.maxLevel then
				row.info.Text = `{def.text}. Rare chances ×{now}.`
				row.buy.Text = "Max level"
				W.setEnabled(row.buy, false)
			else
				local cost = def.cost(level)
				row.info.Text = `{def.text}. Rare chances ×{now} → ×{def.mult(level + 1)}.`
				row.buy.Text = `Buy · {W.number(cost)} gold`
				W.setEnabled(row.buy, data.gold >= cost)
			end
		end
	end

	return { update = update }
end

return UpgradesTab
