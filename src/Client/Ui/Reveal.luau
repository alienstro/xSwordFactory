--!strict
-- The reveal for a rare forge result: the screen dims, and a band in the tier colour
-- shows the tier, the sword name, and the odds. A tap closes it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Odds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Odds")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

local Reveal = {}

local SHOW_TIME = 2.6
local MYTHIC = 100000

-- Shows the reveal. `oneIn` is the rarity, `name` is the sword name.
function Reveal.show(ctx: any, oneIn: number, name: string)
	local color = Theme.tierColor(oneIn)
	local mythic = oneIn >= MYTHIC
	local still = W.reducedMotion()

	local layer, overlay = W.overlay(ctx, "Reveal", 95, if still then 0.3 else 1)
	if not still then
		W.tween(overlay, 0.2, { BackgroundTransparency = 0.3 })
	end

	-- The band goes across the full width. A line in the tier colour is on its top and bottom.
	local band = W.new("CanvasGroup", {
		Name = "Band",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, if still then 0.42 else 0.45),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		GroupTransparency = if still then 0 else 1,
		ZIndex = 96,
		Parent = layer,
	})
	local content = W.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 97,
		Parent = band,
	}, { W.padding(Theme.Space.XL, Theme.Space.XL + 4), W.list(Theme.Space.S, false, Enum.HorizontalAlignment.Center) })
	for _, edge in { 0, 1 } do
		local line = W.new("Frame", {
			Name = if edge == 0 then "TopLine" else "BottomLine",
			AnchorPoint = Vector2.new(0, edge),
			Position = UDim2.fromScale(0, edge),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = if mythic then Color3.new(1, 1, 1) else color,
			BorderSizePixel = 0,
			ZIndex = 98,
			Parent = band,
		})
		if mythic then
			W.new("UIGradient", { Color = Theme.Rainbow, Parent = line })
		end
	end

	W.caption(Odds.tierName(oneIn), {
		TextColor3 = color,
		TextSize = Theme.TextSize.Small,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		ZIndex = 98,
		Parent = content,
	})
	W.label({
		Text = string.upper(name),
		Font = Theme.FontDisplay,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		ZIndex = 98,
		Parent = content,
	})
	W.label({
		Text = Odds.format(oneIn),
		Font = Theme.FontMono,
		TextSize = Theme.TextSize.Title,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
		ZIndex = 98,
		Parent = content,
	})
	W.label({
		Text = "Tap to continue",
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Faint,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 4,
		ZIndex = 98,
		Parent = content,
	})

	if not still then
		W.tween(band, 0.22, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.42) })
	end
	W.sound("Rare")

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		layer:Destroy()
	end
	overlay.Activated:Connect(close)
	task.delay(SHOW_TIME, close)
end

return Reveal
