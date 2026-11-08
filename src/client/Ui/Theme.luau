--!strict
-- Colours, fonts, and sounds of the casino-style UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Odds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Odds")) :: any

local Theme = {}

Theme.Background = Color3.fromRGB(15, 11, 30)
Theme.BackgroundTop = Color3.fromRGB(34, 20, 64)
Theme.Panel = Color3.fromRGB(27, 21, 53)
Theme.PanelLight = Color3.fromRGB(39, 31, 74)
Theme.Button = Color3.fromRGB(58, 47, 107)
Theme.Text = Color3.fromRGB(255, 255, 255)
Theme.Muted = Color3.fromRGB(164, 157, 200)
Theme.Gold = Color3.fromRGB(255, 200, 61)
Theme.Good = Color3.fromRGB(61, 220, 132)
Theme.Bad = Color3.fromRGB(255, 77, 106)
Theme.PrimaryA = Color3.fromRGB(255, 95, 143) -- pink
Theme.PrimaryB = Color3.fromRGB(255, 177, 61) -- orange

Theme.Font = Enum.Font.BuilderSans
Theme.FontBold = Enum.Font.BuilderSansBold
Theme.FontDisplay = Enum.Font.FredokaOne

-- Colours of the rarity tiers: Common, Uncommon, Rare, Epic, Legendary, Mythic.
Theme.Tiers = {
	Color3.fromRGB(184, 188, 200),
	Color3.fromRGB(76, 224, 138),
	Color3.fromRGB(63, 169, 255),
	Color3.fromRGB(182, 92, 255),
	Color3.fromRGB(255, 182, 39),
	Color3.fromRGB(255, 61, 110),
}

Theme.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 61, 110)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 182, 39)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(76, 224, 138)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(63, 169, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(182, 92, 255)),
})

-- Sounds from the Studio content folder. A missing file only gives a warning.
Theme.Sounds = {
	Tick = "rbxasset://sounds/clickfast.wav",
	Rare = "rbxasset://sounds/electronicpingshort.wav",
	Hit = "rbxasset://sounds/swordslash.wav",
	Win = "rbxasset://sounds/victory.wav",
	Click = "rbxasset://sounds/button.wav",
}

function Theme.tierColor(oneIn: number): Color3
	return Theme.Tiers[Odds.tier(oneIn)]
end

function Theme.tier(oneIn: number): number
	return Odds.tier(oneIn)
end

return Theme
