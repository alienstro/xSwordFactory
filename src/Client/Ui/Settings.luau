--!strict
-- The Settings sheet: on/off switches for the music and the sound effects.
-- The server saves each choice, so the choice stays for the next visit.

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any
local Sheet = require(script.Parent.Sheet) :: any

local Settings = {}

local ROWS = {
	{ key = "music", title = "Music", text = "Quiet background music." },
	{ key = "effects", title = "Sound effects", text = "Forge, fight, and button sounds." },
}
local SWITCH_WIDTH = 96

-- Turns the music and the sound effects on or off to match the saved settings.
function Settings.apply(state: any)
	local settings = state.data.settings
	if settings then
		W.setEffects(settings.effects)
		W.setMusic(settings.music)
	end
end

function Settings.open(ctx: any)
	Sheet.open(ctx, "Settings", function(body, _close)
		local switches: { [string]: TextButton } = {}
		for i, row in ROWS do
			local frame = W.new("Frame", {
				Name = row.key,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
				LayoutOrder = i,
				Parent = body,
			})
			W.label({
				Text = row.title,
				Font = Theme.FontMedium,
				TextSize = Theme.TextSize.Body,
				TextWrapped = false,
				Size = UDim2.new(1, -(SWITCH_WIDTH + Theme.Space.M), 0, 22),
				Parent = frame,
			})
			W.label({
				Text = row.text,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Muted,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(0, 24),
				Size = UDim2.new(1, -(SWITCH_WIDTH + Theme.Space.M), 0, 18),
				Parent = frame,
			})
			switches[row.key] = W.button("", {
				Name = "Switch",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(SWITCH_WIDTH, Theme.ControlHeight),
				TextSize = Theme.TextSize.Small,
				Parent = frame,
			}, function()
				local on = ctx.state.data.settings[row.key]
				ctx.request("SetSetting", { key = row.key, on = not on })
			end)
		end

		-- The sheet runs this after each state change, so a switch always shows the saved value.
		return function(state)
			for key, button in switches do
				local on = state.data.settings[key]
				button.Text = if on then "On" else "Off"
				W.setVariant(button, if on then "secondary" else "quiet")
			end
		end
	end)
end

return Settings
