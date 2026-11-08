--!strict
-- A sheet: a panel that opens over the menu, with a dark scrim that covers the full screen.
-- Only one sheet is open at a time. A tap on the scrim closes it.

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

local Sheet = {}

local HEADER_HEIGHT = 36
local PANEL_PADDING = Theme.Space.L + 4
local BODY_PADDING = 2
local BODY_MAX_HEIGHT = 520
-- The height around the body: the top and bottom margins, the panel padding, the header, and the gap.
local SHEET_CHROME = 2 * Theme.Space.L + 2 * PANEL_PADDING + HEADER_HEIGHT + Theme.Space.M

type Open = { layer: Frame, update: ((any) -> ())? }
local current: Open? = nil

function Sheet.close()
	if current then
		current.layer:Destroy()
		current = nil
	end
end

function Sheet.isOpen(): boolean
	return current ~= nil
end

-- Opens a sheet. `build(body, close)` fills the body and can return an
-- update(state) function that runs after each state change.
function Sheet.open(ctx: any, title: string, build: (Frame, () -> ()) -> ((any) -> ())?)
	Sheet.close()

	local layer, scrim = W.overlay(ctx, "SheetLayer", 70, 0.4)
	scrim.Activated:Connect(function()
		Sheet.close()
	end)

	local panel = W.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Theme.Space.L),
		Size = UDim2.new(1, -2 * Theme.Space.L, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		ZIndex = 71,
		Name = "Sheet",
		Parent = layer,
	}, {
		W.corner(Theme.Radius.Surface),
		W.padding(PANEL_PADDING),
		W.maxWidth(Theme.ColumnWidth),
		W.stroke(Theme.Line, 1),
		W.list(Theme.Space.M),
	})

	local header = W.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, HEADER_HEIGHT), LayoutOrder = 0, Parent = panel })
	W.label({
		Text = string.upper(title),
		Font = Theme.FontDisplay,
		TextSize = Theme.TextSize.Title,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -48, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = header,
	})
	W.button("Close", {
		Name = "Close",
		variant = "quiet",
		Size = UDim2.fromOffset(64, 36),
		Position = UDim2.new(1, -64, 0, 0),
		TextSize = Theme.TextSize.Small,
		Parent = header,
	}, function()
		Sheet.close()
	end)

	-- The body scrolls when the content is taller than the free screen height.
	-- Do not use AutomaticSize on this ScrollingFrame: the auto-sized panel then
	-- counts the body too short, and the last buttons go below the screen.
	local body = W.scroll({
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = panel,
	})
	local layout = W.list(Theme.Space.M)
	layout.Parent = body
	W.padding(BODY_PADDING).Parent = body

	-- AbsoluteContentSize and AbsoluteSize include the root UIScale, so divide by it.
	local rootScale = ctx.root:FindFirstChildOfClass("UIScale") :: UIScale?
	local function fitBody()
		local s = if rootScale then rootScale.Scale else 1
		-- UDim.Offset is an integer. Round up, or the canvas is a fraction taller and a scroll bar shows.
		local content = math.ceil(layout.AbsoluteContentSize.Y / s) + 2 * BODY_PADDING
		local room = layer.AbsoluteSize.Y / s - SHEET_CHROME
		body.Size = UDim2.new(1, 0, 0, math.max(0, math.min(content, room, BODY_MAX_HEIGHT)))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitBody)
	layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBody)

	local open: Open = { layer = layer, update = nil }
	current = open
	open.update = build(body, function()
		if current == open then
			Sheet.close()
		end
	end)
	if open.update and ctx.state then
		open.update(ctx.state)
	end
	fitBody()
	W.pop(panel, 0.95)
end

-- Runs the update function of the open sheet.
function Sheet.update(state: any)
	if current and current.update then
		current.update(state)
	end
end

-- Asks the player to confirm an action that cannot be undone.
function Sheet.confirm(ctx: any, title: string, text: string, okText: string, onOk: () -> ())
	Sheet.open(ctx, title, function(body, close)
		W.label({ Text = text, TextSize = Theme.TextSize.Body, TextColor3 = Theme.Muted, LayoutOrder = 1, Parent = body })
		local row = W.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
			LayoutOrder = 2,
			Parent = body,
		}, {
			W.new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 1, 0), CellPadding = UDim2.fromOffset(12, 0) }),
		})
		W.button("Cancel", { LayoutOrder = 1, Parent = row }, close)
		W.button(okText, { LayoutOrder = 2, variant = "danger", Parent = row }, function()
			close()
			onOk()
		end)
		return nil
	end)
end

return Sheet
