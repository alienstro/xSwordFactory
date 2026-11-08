--!strict
-- Design tokens of the UI: colours, type, spacing, and sounds.
-- The look is a forge workshop: warm charcoal, steel text, one ember accent.
-- Change a value here, not in a component.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Odds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Odds")) :: any

local Theme = {}

-- Surfaces, from back to front.
Theme.Background = Color3.fromRGB(17, 16, 15)
Theme.Surface = Color3.fromRGB(27, 25, 23)
Theme.Raised = Color3.fromRGB(37, 34, 31)
Theme.Line = Color3.fromRGB(51, 47, 42) -- hairline dividers

-- Text.
Theme.Text = Color3.fromRGB(242, 237, 230)
Theme.Muted = Color3.fromRGB(163, 155, 145)
Theme.Faint = Color3.fromRGB(112, 105, 97)

-- Meaning.
Theme.Accent = Color3.fromRGB(232, 106, 44) -- ember: the main action only
Theme.AccentText = Color3.fromRGB(255, 248, 240)
Theme.Gold = Color3.fromRGB(230, 178, 76) -- money only
Theme.Good = Color3.fromRGB(110, 196, 132)
Theme.Bad = Color3.fromRGB(229, 92, 80)
Theme.DangerSurface = Color3.fromRGB(58, 32, 29)

-- Old names. The tabs used these before the redesign.
Theme.Panel = Theme.Surface
Theme.PanelLight = Theme.Raised
Theme.Button = Theme.Raised
Theme.BackgroundTop = Theme.Background

-- Type. Oswald is for names and the title, RobotoMono for odds and numbers.
Theme.Font = Enum.Font.BuilderSans
Theme.FontMedium = Enum.Font.BuilderSansMedium
Theme.FontBold = Enum.Font.BuilderSansBold
Theme.FontDisplay = Enum.Font.Oswald
Theme.FontMono = Enum.Font.RobotoMono

Theme.TextSize = {
	Caption = 12, -- small caps labels
	Small = 14,
	Body = 16,
	Lead = 18,
	Title = 22,
	Name = 30, -- a sword name on the result card
}

-- Spacing scale. Use only these steps.
Theme.Space = { XS = 4, S = 8, M = 12, L = 16, XL = 24 }

Theme.Radius = { Control = 6, Surface = 10 }

Theme.ColumnWidth = 640 -- the content column on wide screens
Theme.ControlHeight = 44
Theme.PrimaryHeight = 60

-- Colours of the rarity tiers: Common, Uncommon, Rare, Epic, Legendary, Mythic.
Theme.Tiers = {
	Color3.fromRGB(176, 172, 165),
	Color3.fromRGB(110, 196, 132),
	Color3.fromRGB(92, 160, 230),
	Color3.fromRGB(176, 120, 230),
	Color3.fromRGB(240, 176, 64),
	Color3.fromRGB(240, 84, 96),
}

-- Kept for the rare-roll reveal only.
Theme.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Theme.Tiers[6]),
	ColorSequenceKeypoint.new(0.5, Theme.Tiers[5]),
	ColorSequenceKeypoint.new(1, Theme.Tiers[4]),
})

-- UI sounds. Each one has an audio asset, a volume, and a pitch spread.
-- A spread of 0.05 plays each time at a random pitch from 0.95 to 1.05, so a repeated sound does not tire the ear.
-- All assets come from Roblox, Pro Sound Effects, or APM Music. Each experience can use them.
-- To change a sound, change only its id here.
export type SoundDef = { id: string, volume: number, spread: number }
Theme.Sounds = {
	Click = { id = "rbxassetid://15675032796", volume = 0.25, spread = 0.05 }, -- Roblox_UI_Small_Click
	Spin = { id = "rbxassetid://15675032796", volume = 0.08, spread = 0.12 }, -- Roblox_UI_Small_Click, played fast while the reels turn
	Forge = { id = "rbxassetid://9116651251", volume = 0.45, spread = 0.04 }, -- Metal Hits 1: a hammer on metal
	Stop = { id = "rbxassetid://9116653976", volume = 0.4, spread = 0.03 }, -- Metal Hits 5: a reel stops
	Result = { id = "rbxassetid://15675043410", volume = 0.35, spread = 0 }, -- Roblox_UI_Tonal_Stinger: the pitch goes up with the tier
	Rare = { id = "rbxassetid://87681931953984", volume = 0.6, spread = 0 }, -- Vast Horizon - Sting: 1 in 1,000 or rarer
	Hit = { id = "rbxassetid://9116554603", volume = 0.35, spread = 0.1 }, -- Metal Crown Hit Clang
	Win = { id = "rbxassetid://9038514384", volume = 0.45, spread = 0 }, -- Halfway to Rio (sting b): a celebration
	Lose = { id = "rbxassetid://15675062723", volume = 0.4, spread = 0 }, -- Roblox_UI_Whistle_Low
	Success = { id = "rbxassetid://15675043410", volume = 0.35, spread = 0.03 }, -- Roblox_UI_Tonal_Stinger: an upgrade or an enhance works
	Fail = { id = "rbxassetid://15675062723", volume = 0.35, spread = 0.03 }, -- Roblox_UI_Whistle_Low: an enhance fails
	Equip = { id = "rbxassetid://9125495498", volume = 0.4, spread = 0.06 }, -- Dowel Swish: a blade moves
	Salvage = { id = "rbxassetid://15675075163", volume = 0.35, spread = 0.04 }, -- Roblox_UI_Delete
} :: { [string]: SoundDef }

-- The background music. It loops quietly under the sound effects. DistroKid is a licensed Roblox music partner.
Theme.Music = { id = "rbxassetid://84803923909075", volume = 0.15 } -- Calm Fireplace and Rain Piano
Theme.MusicFadeIn = 2 -- Seconds for the music to go from silent to full volume.

-- The pitch of the Result sound for each tier: Common, Uncommon, Rare, Epic, Legendary, Mythic.
Theme.ResultPitch = { 0.8, 0.9, 1.0, 1.12, 1.25, 1.4 }

function Theme.tierColor(oneIn: number): Color3
	return Theme.Tiers[Odds.tier(oneIn)]
end

function Theme.tier(oneIn: number): number
	return Odds.tier(oneIn)
end

return Theme
