--!strict
-- The big reveal for a rare forge result: the screen dims, light rays turn,
-- a tier banner pops in, and a sound plays. A tap closes it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Odds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Odds")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

local Reveal = {}

local RAYS = 12
local SHOW_TIME = 2.6
local MYTHIC = 100000

-- Shows the reveal. `oneIn` is the rarity, `name` is the sword name.
function Reveal.show(ctx: any, oneIn: number, name: string)
	local color = Theme.tierColor(oneIn)
	local mythic = oneIn >= MYTHIC

	local overlay = W.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 95,
		Parent = ctx.root,
	})
	W.tween(overlay, 0.25, { BackgroundTransparency = 0.25 })

	-- A full-screen flash for the rarest results.
	if mythic then
		local flash = W.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 99,
			Parent = overlay,
		}, { W.new("UIGradient", { Color = Theme.Rainbow, Rotation = 45 }) })
		W.tween(flash, 0.9, { BackgroundTransparency = 1 })
	end

	-- Light rays that turn behind the banner.
	for i = 1, RAYS do
		local ray = W.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(46, 1400),
			Rotation = (i - 1) * (180 / RAYS),
			-- A mythic result gets rays in all tier colours.
			BackgroundColor3 = if mythic then Theme.Tiers[(i % #Theme.Tiers) + 1] else color,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 96,
			Parent = overlay,
		}, {
			W.new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
			}),
		})
		W.tween(ray, SHOW_TIME + 1, { Rotation = ray.Rotation + 120 }, Enum.EasingStyle.Linear)
	end

	local center = W.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(1, -40, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 97,
		Parent = overlay,
	}, { W.list(6, false, Enum.HorizontalAlignment.Center), W.maxWidth(520) })

	local banner = W.label({
		Text = string.upper(Odds.tierName(oneIn)) .. "!",
		Font = Theme.FontDisplay,
		TextSize = 64,
		TextColor3 = if mythic then Color3.new(1, 1, 1) else color,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		LayoutOrder = 1,
		ZIndex = 98,
		Parent = center,
	})
	if mythic then
		W.new("UIGradient", { Color = Theme.Rainbow, Parent = banner })
	end
	W.label({
		Text = name,
		Font = Theme.FontDisplay,
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		ZIndex = 98,
		Parent = center,
	})
	W.label({
		Text = Odds.format(oneIn),
		Font = Theme.FontDisplay,
		TextSize = 40,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
		ZIndex = 98,
		Parent = center,
	})
	W.label({
		Text = "Tap to continue",
		TextSize = 16,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 4,
		ZIndex = 98,
		Parent = center,
	})

	W.pop(center, 0.3)
	W.shake(center, 10, 0.4)
	W.sound("Rare", 0.8)

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		overlay:Destroy()
	end
	overlay.Activated:Connect(close)
	task.delay(SHOW_TIME, close)
end

return Reveal
