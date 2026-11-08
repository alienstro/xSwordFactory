--!strict
-- A sheet: a panel that opens over the menu, with a dark backdrop.
-- Only one sheet is open at a time. A tap on the backdrop closes it.

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any

local Sheet = {}

type Open = { backdrop: TextButton, update: ((any) -> ())? }
local current: Open? = nil

function Sheet.close()
	if current then
		current.backdrop:Destroy()
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

	local backdrop = W.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 70,
		Parent = ctx.root,
	})
	backdrop.Activated:Connect(function()
		Sheet.close()
	end)

	local panel = W.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		ZIndex = 71,
		Parent = backdrop,
	}, {
		W.corner(20),
		W.padding(18),
		W.maxWidth(560),
		W.stroke(Theme.Button, 2),
		W.list(12),
	})

	local header = W.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 0, Parent = panel })
	W.label({
		Text = title,
		Font = Theme.FontDisplay,
		TextSize = 26,
		Size = UDim2.new(1, -48, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
		Parent = header,
	})
	W.button("✕", {
		Size = UDim2.fromOffset(40, 36),
		Position = UDim2.new(1, -40, 0, 0),
		TextSize = 18,
		Parent = header,
	}, function()
		Sheet.close()
	end)

	-- The body scrolls when the content is taller than most of the screen.
	local body = W.scroll({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1,
		Parent = panel,
	})
	W.new("UISizeConstraint", { MaxSize = Vector2.new(math.huge, 520), Parent = body })
	W.list(10).Parent = body
	W.padding(2).Parent = body

	local open: Open = { backdrop = backdrop, update = nil }
	current = open
	open.update = build(body, function()
		if current == open then
			Sheet.close()
		end
	end)
	if open.update and ctx.state then
		open.update(ctx.state)
	end
	W.pop(panel, 0.85)
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
		W.label({ Text = text, TextSize = 18, LayoutOrder = 1, Parent = body })
		local row = W.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 52),
			LayoutOrder = 2,
			Parent = body,
		}, {
			W.new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 1, 0), CellPadding = UDim2.fromOffset(12, 0) }),
		})
		W.button("Cancel", { LayoutOrder = 1, Parent = row }, close)
		W.button(okText, { LayoutOrder = 2, BackgroundColor3 = Theme.Bad, Parent = row }, function()
			close()
			onOk()
		end)
		return nil
	end)
end

return Sheet
