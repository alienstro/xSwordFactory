--!strict
-- Colours and fonts of the UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Odds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Odds")) :: any

local Theme = {}

Theme.Background = Color3.fromRGB(18, 20, 26)
Theme.Panel = Color3.fromRGB(30, 33, 42)
Theme.PanelLight = Color3.fromRGB(42, 46, 58)
Theme.Button = Color3.fromRGB(52, 57, 72)
Theme.ButtonHover = Color3.fromRGB(66, 72, 90)
Theme.Text = Color3.fromRGB(235, 236, 240)
Theme.Muted = Color3.fromRGB(150, 156, 170)
Theme.Accent = Color3.fromRGB(255, 154, 60)
Theme.Good = Color3.fromRGB(94, 209, 122)
Theme.Bad = Color3.fromRGB(229, 83, 75)
Theme.GoldText = Color3.fromRGB(255, 205, 80)

Theme.Font = Enum.Font.BuilderSans
Theme.FontBold = Enum.Font.BuilderSansBold

-- Colours of the rarity tiers 1 to 6: grey, green, blue, purple, gold, red.
Theme.Tiers = {
	Color3.fromRGB(176, 180, 186),
	Color3.fromRGB(94, 209, 122),
	Color3.fromRGB(78, 163, 255),
	Color3.fromRGB(179, 107, 255),
	Color3.fromRGB(255, 200, 61),
	Color3.fromRGB(255, 77, 77),
}

-- The colour of a "1 in N" value.
function Theme.tierColor(oneIn: number): Color3
	return Theme.Tiers[Odds.tier(oneIn)]
end

return Theme
