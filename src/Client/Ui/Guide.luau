--!strict
-- The guide: a small tooltip next to the button that the player must tap next.

local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

type Step = {
	tab: string,
	target: (ctx: any) -> string,
	text: string,
	done: (name: string, result: any) -> boolean,
}

local TOOLTIP_WIDTH = 300
local GAP = 14

-- The name of a target inside a sheet if the sheet shows it, else the fallback target.
local function inSheetOr(ctx: any, name: string, fallback: string): string
	local t = ctx.targets[name]
	if t and t.Parent and t:IsDescendantOf(ctx.root) then
		return name
	end
	return fallback
end

local STEPS: { Step } = {
	{
		tab = "Forge",
		target = function()
			return "ForgeButton"
		end,
		text = "Welcome! Tap <b>FORGE</b> to roll your first sword. Each part of the sword is a chance roll.",
		done = function(name)
			return name == "Forge"
		end,
	},
	{
		tab = "Swords",
		target = function(ctx)
			return inSheetOr(ctx, "EquipButton", "FirstSword")
		end,
		text = "Tap your sword, then tap <b>Equip</b>. Only the equipped sword fights.",
		done = function(name)
			return name == "Equip"
		end,
	},
	{
		tab = "Fight",
		target = function(ctx)
			return if ctx.state and ctx.state.fight then "AttackButton" else "FirstMonster"
		end,
		text = "Fight the <b>Slime</b>. Tap <b>Attack</b> until you win, or turn on <b>AUTO</b>.",
		done = function(name, result)
			return name == "FightTurn" and result.outcome == "win"
		end,
	},
	{
		tab = "Swords",
		target = function(ctx)
			return inSheetOr(ctx, "EnhanceButton", "FirstSword")
		end,
		text = "Open your sword and tap <b>Enhance</b>. An attempt can fail, but the sword keeps its level.",
		done = function(name)
			return name == "Enhance"
		end,
	},
	{
		tab = "Swords",
		target = function(ctx)
			return inSheetOr(ctx, "EnchantButton", "FirstSword")
		end,
		text = "If your sword has an empty slot, tap <b>Enchant</b>. Forge more swords to find more slots. Good luck!",
		done = function(name)
			return name == "Enchant"
		end,
	},
}

local Guide = {}

local tooltip: Frame
local stepLabel: TextLabel
local textLabel: TextLabel
local nextButton: TextButton
local stroke: UIStroke
local current = 0 -- 0 means that the guide is not active
local follow: RBXScriptConnection? = nil

local function finish(ctx: any)
	current = 0
	Guide.update(ctx)
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
	W.pop(tooltip, 0.85)
end

local function targetOf(ctx: any): GuiObject?
	if current == 0 then
		return nil
	end
	local step = STEPS[current]
	local name = if ctx.currentTab == step.tab then step.target(ctx) else step.tab .. "Tab"
	local target = ctx.targets[name]
	if target and target.Parent and target:IsDescendantOf(ctx.root) then
		return target
	end
	return nil
end

-- Puts the tooltip above or below the target, inside the screen.
local function place(ctx: any)
	local target = targetOf(ctx)
	if not target then
		tooltip.Position = UDim2.new(0.5, -TOOLTIP_WIDTH / 2, 0, 80)
		return
	end
	local root = ctx.root :: Frame
	local s = (root:FindFirstChildOfClass("UIScale") :: UIScale).Scale
	local rootPos = root.AbsolutePosition
	local rootSize = root.AbsoluteSize / s
	local pos = (target.AbsolutePosition - rootPos) / s
	local size = target.AbsoluteSize / s
	local height = tooltip.AbsoluteSize.Y / s

	-- A tab button is at the bottom, below the main action. The stroke shows the tab,
	-- and the tooltip waits near the top, so that it does not cover the main action.
	if target.Name:match("Tab$") then
		tooltip.Position = UDim2.fromOffset(math.max(8, rootSize.X / 2 - TOOLTIP_WIDTH / 2), 76)
		return
	end

	local x = math.clamp(pos.X + size.X / 2 - TOOLTIP_WIDTH / 2, 8, rootSize.X - TOOLTIP_WIDTH - 8)
	local below = pos.Y + size.Y + GAP
	local above = pos.Y - GAP - height
	local y = if pos.Y + size.Y / 2 < rootSize.Y / 2 then below else above
	y = math.clamp(y, 8, rootSize.Y - height - 8)
	tooltip.Position = UDim2.fromOffset(x, y)
end

function Guide.create(ctx: any)
	tooltip = W.new("Frame", {
		Name = "GuideTip",
		Size = UDim2.fromOffset(TOOLTIP_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Raised,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 75,
		Parent = ctx.root,
	}, { W.corner(Theme.Radius.Surface), W.padding(Theme.Space.L - 2), W.stroke(Theme.Line, 1), W.list(Theme.Space.S) })
	stepLabel = W.caption("", { TextColor3 = Theme.Accent, LayoutOrder = 1, ZIndex = 76, Parent = tooltip })
	textLabel = W.label({ Text = "", TextSize = Theme.TextSize.Body, LayoutOrder = 2, ZIndex = 76, Parent = tooltip })
	local row = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 3,
		ZIndex = 76,
		Parent = tooltip,
	}, {
		W.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 1, 0),
			CellPadding = UDim2.fromOffset(8, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})
	W.button("Skip guide", { variant = "quiet", LayoutOrder = 1, TextSize = Theme.TextSize.Small, ZIndex = 77, Parent = row }, function()
		finish(ctx)
	end)
	nextButton = W.button("Next", { LayoutOrder = 2, BackgroundColor3 = Theme.Line, TextSize = Theme.TextSize.Small, ZIndex = 77, Parent = row }, function()
		advance(ctx)
	end)

	-- A still ring around the target. It does not pulse, so it does not pull the eye all the time.
	stroke = W.new("UIStroke", {
		Name = "GuideRing",
		Color = Theme.Accent,
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

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
	W.pop(tooltip, 0.85)
end

-- Shows the current step and points to its button.
function Guide.update(ctx: any)
	if current == 0 then
		tooltip.Visible = false
		stroke.Parent = nil
		if follow then
			follow:Disconnect()
			follow = nil
		end
		return
	end
	local step = STEPS[current]
	tooltip.Visible = true
	stepLabel.Text = `GUIDE  ·  STEP {current} OF {#STEPS}`
	textLabel.Text = step.text
	nextButton.Text = if current == #STEPS then "Finish" else "Next"
	stroke.Parent = targetOf(ctx)
	if not follow then
		-- The target can move (for example, when a sheet opens), so the tooltip follows it.
		follow = RunService.RenderStepped:Connect(function()
			stroke.Parent = targetOf(ctx)
			place(ctx)
		end)
	end
	place(ctx)
end

return Guide
