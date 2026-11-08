--!strict
-- The guide: it shows one step at a time and points to the next button.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

type Step = {
	tab: string,
	target: (ctx: any) -> string,
	text: string,
	done: (name: string, result: any) -> boolean,
}

local STEPS: { Step } = {
	{
		tab = "Forge",
		target = function()
			return "ForgeButton"
		end,
		text = "Welcome to Sword Factory! Click <b>Forge</b> to make your first sword. Each part of the sword is a chance roll.",
		done = function(name)
			return name == "Forge"
		end,
	},
	{
		tab = "Swords",
		target = function()
			return "EquipButton"
		end,
		text = "Open the <b>Swords</b> tab and click <b>Equip</b>. Only the equipped sword fights.",
		done = function(name)
			return name == "Equip"
		end,
	},
	{
		tab = "Fight",
		target = function(ctx)
			return if ctx.state and ctx.state.fight then "AttackButton" else "FirstMonster"
		end,
		text = "Open the <b>Fight</b> tab and fight the <b>Slime</b>. Click <b>Attack</b> until you win.",
		done = function(name, result)
			return name == "FightTurn" and result.outcome == "win"
		end,
	},
	{
		tab = "Swords",
		target = function()
			return "EnhanceButton"
		end,
		text = "Use your gold to <b>Enhance</b> your sword. An attempt can fail, but the sword keeps its level.",
		done = function(name)
			return name == "Enhance"
		end,
	},
	{
		tab = "Swords",
		target = function()
			return "EnchantButton"
		end,
		text = "If your sword has an empty slot, click <b>Enchant</b>. Forge more swords to find more slots. Good luck!",
		done = function(name)
			return name == "Enchant"
		end,
	},
}

local Guide = {}

local panel: Frame
local stepLabel: TextLabel
local textLabel: TextLabel
local nextButton: TextButton
local stroke: UIStroke
local current = 0 -- 0 means that the guide is not active

local function finish(ctx: any)
	current = 0
	panel.Visible = false
	stroke.Parent = nil
	if ctx.state and not ctx.state.data.guideDone then
		ctx.request("FinishGuide")
	end
end

local function advance(ctx: any)
	if current >= #STEPS then
		finish(ctx)
		return
	end
	current += 1
	Guide.update(ctx)
end

function Guide.create(ctx: any)
	panel = W.panel({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -80),
		Size = UDim2.new(0, 380, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(40, 34, 28),
		Visible = false,
		ZIndex = 60,
		Parent = ctx.root,
	})
	W.new("UIStroke", { Color = Theme.Accent, Thickness = 2, Parent = panel })
	W.list(8).Parent = panel
	stepLabel = W.label({ Text = "", TextColor3 = Theme.Accent, Font = Theme.FontBold, TextSize = 16, LayoutOrder = 1, Parent = panel })
	textLabel = W.label({ Text = "", TextSize = 19, LayoutOrder = 2, Parent = panel })
	local row = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 3,
		Parent = panel,
	}, {
		W.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 1, 0),
			CellPadding = UDim2.new(0, 8, 0, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	W.button("Skip guide", { LayoutOrder = 1, TextSize = 16, Parent = row }, function()
		finish(ctx)
	end)
	nextButton = W.button("Next", { LayoutOrder = 2, TextSize = 16, Parent = row }, function()
		advance(ctx)
	end)

	stroke = W.new("UIStroke", {
		Color = Theme.Accent,
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	TweenService:Create(
		stroke,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8 }
	):Play()

	table.insert(ctx.listeners, function(name: string, _args, result)
		if current == 0 or not result.ok then
			return
		end
		if STEPS[current].done(name, result) then
			advance(ctx)
		end
	end)
end

function Guide.start(ctx: any)
	current = 1
	Guide.update(ctx)
end

-- Shows the current step and points to its button.
function Guide.update(ctx: any)
	if current == 0 then
		panel.Visible = false
		stroke.Parent = nil
		return
	end
	local step = STEPS[current]
	panel.Visible = true
	stepLabel.Text = `GUIDE · STEP {current} OF {#STEPS}`
	textLabel.Text = step.text
	nextButton.Text = if current == #STEPS then "Finish" else "Next"

	local targetName = if ctx.currentTab == step.tab then step.target(ctx) else step.tab .. "Tab"
	local target = ctx.targets[targetName]
	stroke.Parent = if target and target.Parent then target else nil
end

return Guide
