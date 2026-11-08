--!strict
-- Small components that make UI Instances and short animations.
-- Every colour, size, and radius comes from Theme.

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme) :: any

local W = {}

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end
W.reducedMotion = reducedMotion

-- Makes an Instance, sets its properties, and adds its children.
function W.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className) :: any
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function W.corner(radius: number?): UICorner
	return W.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius.Surface) })
end

function W.padding(px: number, py: number?): UIPadding
	return W.new("UIPadding", {
		PaddingTop = UDim.new(0, py or px),
		PaddingBottom = UDim.new(0, py or px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function W.list(gap: number, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	return W.new("UIListLayout", {
		Padding = UDim.new(0, gap),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function W.stroke(color: Color3, thickness: number?, transparency: number?): UIStroke
	return W.new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function W.gradient(a: Color3, b: Color3, rotation: number?): UIGradient
	return W.new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rotation or 90 })
end

-- Limits the width of a frame, so that it stays readable on a wide screen.
function W.maxWidth(px: number): UISizeConstraint
	return W.new("UISizeConstraint", { MaxSize = Vector2.new(px, math.huge) })
end

-- The centred content column of a page. All pages use the same width.
function W.column(page: Instance, name: string?): Frame
	return W.new("Frame", {
		Name = name or "Column",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, -2 * Theme.Space.L, 1, 0),
		BackgroundTransparency = 1,
		Parent = page,
	}, { W.maxWidth(Theme.ColumnWidth) })
end

-- A flat panel. Its height follows its content unless `Size` has a height.
function W.card(props: { [string]: any }): Frame
	local p = table.clone(props)
	p.BackgroundColor3 = p.BackgroundColor3 or Theme.Surface
	p.BorderSizePixel = 0
	if not p.Size then
		p.Size = UDim2.new(1, 0, 0, 0)
		p.AutomaticSize = Enum.AutomaticSize.Y
	end
	return W.new("Frame", p, { W.corner(Theme.Radius.Surface), W.padding(Theme.Space.L) })
end

-- A flat panel with a thin colour stripe on the left edge, for example the rarity of a sword.
-- Returns the panel, the body that holds the content, and a function that sets the stripe colour.
function W.accentCard(props: { [string]: any }): (Frame, Frame, (Color3?) -> ())
	local p = table.clone(props)
	p.BackgroundColor3 = p.BackgroundColor3 or Theme.Surface
	p.BorderSizePixel = 0
	p.ClipsDescendants = true
	if not p.Size then
		p.Size = UDim2.new(1, 0, 0, 0)
		p.AutomaticSize = Enum.AutomaticSize.Y
	end
	local outer = W.new("Frame", p, { W.corner(Theme.Radius.Surface) })
	local stripe = W.new("Frame", {
		Name = "Stripe",
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Theme.Line,
		BorderSizePixel = 0,
		Parent = outer,
	})
	local body = W.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = outer,
	}, { W.padding(Theme.Space.L) })
	local function setAccent(color: Color3?)
		stripe.BackgroundColor3 = color or Theme.Line
	end
	return outer, body, setAccent
end

function W.label(props: { [string]: any }): TextLabel
	local p = table.clone(props)
	p.BackgroundTransparency = p.BackgroundTransparency or 1
	p.Font = p.Font or Theme.Font
	p.TextColor3 = p.TextColor3 or Theme.Text
	p.TextSize = p.TextSize or Theme.TextSize.Body
	p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
	p.TextWrapped = if p.TextWrapped == nil then true else p.TextWrapped
	p.RichText = true
	if not p.Size then
		p.Size = UDim2.new(1, 0, 0, 0)
		p.AutomaticSize = Enum.AutomaticSize.Y
	end
	return W.new("TextLabel", p)
end

-- A small uppercase label above a value, for example "MATERIAL".
function W.caption(text: string, props: { [string]: any }?): TextLabel
	local p = table.clone(props or {})
	p.Text = string.upper(text)
	p.Font = p.Font or Theme.FontBold
	p.TextSize = p.TextSize or Theme.TextSize.Caption
	p.TextColor3 = p.TextColor3 or Theme.Faint
	return W.label(p)
end

-- A 1-pixel line that separates two groups.
function W.divider(props: { [string]: any }?): Frame
	local p = table.clone(props or {})
	p.BackgroundColor3 = Theme.Line
	p.BorderSizePixel = 0
	p.Size = p.Size or UDim2.new(1, 0, 0, 1)
	return W.new("Frame", p)
end

-- All UI sounds play in one SoundGroup, so one volume setting can control them all.
local soundGroup: SoundGroup? = nil
local soundTemplates: { [string]: Sound } = {}
local effectsOn = true
local music: Sound? = nil

local function templates(): { [string]: Sound }
	if not soundGroup then
		local group = W.new("SoundGroup", { Name = "UISounds", Volume = 1, Parent = SoundService })
		soundGroup = group
		for name, def in Theme.Sounds do
			soundTemplates[name] = W.new("Sound", { Name = name, SoundId = def.id, Volume = def.volume, SoundGroup = group, Parent = group })
		end
	end
	return soundTemplates
end

-- Loads the audio of all UI sounds, so that the first play has no delay. Call it one time at the start.
function W.preloadSounds()
	local list = {}
	for _, sound in templates() do
		table.insert(list, sound)
	end
	task.spawn(function()
		ContentProvider:PreloadAsync(list)
	end)
end

-- Plays a UI sound by name from Theme.Sounds. `pitch` multiplies the pitch, for example to rise with a tier.
-- Each play uses a new copy, so a sound can overlap with itself and keep its own pitch.
function W.sound(name: string, pitch: number?)
	if not effectsOn then
		return
	end
	local template = templates()[name]
	if not template then
		return
	end
	local spread = Theme.Sounds[name].spread
	local sound = template:Clone()
	sound.PlaybackSpeed = (pitch or 1) * (1 + (math.random() * 2 - 1) * spread)
	sound.Parent = soundGroup
	sound:Play()
	-- The longest sound is about 6 seconds. Debris also removes a copy that did not load.
	Debris:AddItem(sound, 10)
end

-- Turns the sound effects on or off. The player setting is saved on the server.
function W.setEffects(on: boolean)
	effectsOn = on
	local group = soundGroup
	if group then
		group.Volume = if on then 1 else 0 -- also silences effects that already play
	end
end

-- Turns the background music on or off. The music loops in its own SoundGroup.
-- Off pauses the track, so it uses no resources. On fades it in again.
function W.setMusic(on: boolean)
	if not music then
		if not on then
			return
		end
		local group = W.new("SoundGroup", { Name = "Music", Volume = 1, Parent = SoundService })
		music = W.new("Sound", { Name = "Music", SoundId = Theme.Music.id, Looped = true, Volume = 0, SoundGroup = group, Parent = group })
	end
	local track = music :: Sound
	if on and not track.IsPlaying then
		track.Volume = 0
		track:Resume()
		W.tween(track, Theme.MusicFadeIn, { Volume = Theme.Music.volume }, Enum.EasingStyle.Linear)
	elseif not on and track.IsPlaying then
		track:Pause()
	end
end

function W.tween(obj: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function scaleOf(obj: GuiObject): UIScale
	local s = obj:FindFirstChild("PopScale") :: UIScale?
	if not s then
		s = W.new("UIScale", { Name = "PopScale", Parent = obj })
	end
	return s :: UIScale
end

-- Grows an object a little to show that it changed. No bounce.
function W.pop(obj: GuiObject, from: number?)
	if reducedMotion() then
		return
	end
	local s = scaleOf(obj)
	s.Scale = 1 - (1 - (from or 0.9)) * 0.3
	W.tween(s, 0.16, { Scale = 1 })
end

-- Moves an object a little from side to side, then puts it back. For a hit only.
function W.shake(obj: GuiObject, strength: number?, time: number?)
	if reducedMotion() then
		return
	end
	task.spawn(function()
		local origin = obj.Position
		local amount = math.min(strength or 4, 4)
		local stop = os.clock() + math.min(time or 0.2, 0.2)
		while os.clock() < stop and obj.Parent do
			obj.Position = origin + UDim2.fromOffset(math.random(-amount, amount), 0)
			task.wait(0.03)
		end
		obj.Position = origin
	end)
end

-- The colours of each button role.
local VARIANTS = {
	primary = { bg = Theme.Accent, text = Theme.AccentText, font = Theme.FontBold },
	secondary = { bg = Theme.Raised, text = Theme.Text, font = Theme.FontMedium },
	quiet = { bg = Theme.Raised, text = Theme.Muted, font = Theme.FontMedium, transparent = true },
	danger = { bg = Theme.DangerSurface, text = Theme.Bad, font = Theme.FontMedium },
}

local function paint(button: TextButton, hovered: boolean)
	local v = VARIANTS[button:GetAttribute("Variant") or "secondary"]
	local enabled = button.Active
	local base: Color3 = button:GetAttribute("BaseColor") or v.bg
	if not enabled then
		button.BackgroundColor3 = Theme.Surface
		button.BackgroundTransparency = if v.transparent then 1 else 0
		button.TextColor3 = Theme.Faint
		return
	end
	button.TextColor3 = button:GetAttribute("TextColor") or v.text
	if v.transparent then
		button.BackgroundColor3 = base
		button.BackgroundTransparency = if hovered then 0 else 1
		if hovered then
			button.TextColor3 = Theme.Text
		end
	else
		button.BackgroundTransparency = 0
		button.BackgroundColor3 = if hovered then base:Lerp(Color3.new(1, 1, 1), 0.07) else base
	end
end

-- Makes a button. `onClick` runs when the player clicks it.
-- Set `variant` to "primary" (the one main action), "secondary", "quiet", or "danger".
-- `primary = true` is the same as `variant = "primary"`.
function W.button(text: string, props: { [string]: any }, onClick: () -> ()): TextButton
	local p = table.clone(props)
	local variant = p.variant or (if p.primary then "primary" else "secondary")
	p.variant = nil
	p.primary = nil
	local v = VARIANTS[variant] or VARIANTS.secondary
	local customColor = p.BackgroundColor3
	p.BackgroundColor3 = customColor or v.bg
	p.BorderSizePixel = 0
	p.AutoButtonColor = false
	p.Font = p.Font or v.font
	p.TextSize = p.TextSize or Theme.TextSize.Body
	p.Text = text
	p.Size = p.Size or UDim2.new(1, 0, 0, Theme.ControlHeight)
	local button = W.new("TextButton", p, { W.corner(Theme.Radius.Control) })
	button:SetAttribute("Variant", variant)
	button:SetAttribute("Primary", variant == "primary")
	button:SetAttribute("BaseColor", customColor or v.bg)
	if p.TextColor3 then
		button:SetAttribute("TextColor", p.TextColor3)
	end
	paint(button, false)

	local s = scaleOf(button)
	local hovered = false
	button.MouseEnter:Connect(function()
		hovered = true
		paint(button, true)
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		paint(button, false)
		s.Scale = 1
	end)
	button.SelectionGained:Connect(function()
		paint(button, true)
	end)
	button.SelectionLost:Connect(function()
		paint(button, hovered)
	end)
	button.MouseButton1Down:Connect(function()
		if button.Active and not reducedMotion() then
			W.tween(s, 0.06, { Scale = 0.97 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		W.tween(s, 0.1, { Scale = 1 })
	end)
	button:GetPropertyChangedSignal("Active"):Connect(function()
		paint(button, hovered)
	end)
	button.Activated:Connect(function()
		if button.Active then
			W.sound("Click")
			onClick()
		end
	end)
	return button
end

-- Changes the background colour of a button. Hover keeps this colour.
function W.setColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	paint(button, false)
end

-- Changes the role of a button, for example from "secondary" to "primary".
function W.setVariant(button: TextButton, variant: string)
	button:SetAttribute("Variant", variant)
	button:SetAttribute("Primary", variant == "primary")
	button:SetAttribute("BaseColor", VARIANTS[variant].bg)
	button.Font = VARIANTS[variant].font
	paint(button, false)
end

-- Turns a button on or off. An off button is flat and does not react.
function W.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	paint(button, false)
end

-- Makes an overlay for a sheet or a reveal. Destroy the layer to close the overlay.
-- The layer has the size of ctx.root, so its content stays in the safe area.
-- The scrim in the layer covers the full screen, also the strip behind the Roblox top bar.
function W.overlay(ctx: any, name: string, zIndex: number, transparency: number): (Frame, TextButton)
	local layer = W.new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = zIndex,
		Parent = ctx.root,
	})
	local scrim = W.new("TextButton", {
		Name = "Scrim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Parent = layer,
	})

	-- Absolute values include the root UIScale, so divide by it.
	-- UDim.Offset is an integer: round outward, or a thin line of the screen stays light.
	local full: GuiBase2d = ctx.fullScreen
	local scale = ctx.root:FindFirstChildOfClass("UIScale") :: UIScale?
	local function fit()
		local s = if scale then scale.Scale else 1
		local offset = (full.AbsolutePosition - layer.AbsolutePosition) / s
		scrim.Position = UDim2.fromOffset(math.floor(offset.X), math.floor(offset.Y))
		scrim.Size = UDim2.fromOffset(math.ceil(full.AbsoluteSize.X / s) + 1, math.ceil(full.AbsoluteSize.Y / s) + 1)
	end
	fit()
	local connections = {
		full:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit),
		full:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit),
		layer:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit),
	}
	if scale then
		table.insert(connections, scale:GetPropertyChangedSignal("Scale"):Connect(fit))
	end
	-- The signals of `full` and `scale` stay after the layer goes, so disconnect them.
	layer.Destroying:Connect(function()
		for _, c in connections do
			c:Disconnect()
		end
	end)
	return layer, scrim
end

function W.scroll(props: { [string]: any }): ScrollingFrame
	local p = table.clone(props)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.ScrollBarThickness = 4
	p.ScrollBarImageColor3 = Theme.Line
	p.CanvasSize = UDim2.new()
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y
	p.ScrollingDirection = Enum.ScrollingDirection.Y
	p.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar -- room for the bar only when it shows
	return W.new("ScrollingFrame", p)
end

-- Removes all children except layouts, padding, corners, and strokes.
function W.clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

-- A horizontal bar that shows a value from 0 to 1, with a caption on it.
function W.bar(color: Color3, props: { [string]: any }): (Frame, (number, string) -> ())
	local p = table.clone(props)
	p.BackgroundColor3 = Theme.Raised
	p.BorderSizePixel = 0
	p.Size = p.Size or UDim2.new(1, 0, 0, 20)
	local fill = W.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, { W.corner(3) })
	local text = W.label({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.FontMono,
		TextSize = 13,
		TextStrokeTransparency = 0.6,
		ZIndex = 2,
	})
	local frame = W.new("Frame", p, { W.corner(3), fill, text })
	local function set(ratio: number, caption: string)
		W.tween(fill, 0.2, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) })
		text.Text = caption
	end
	return frame, set
end

-- A row of small squares that shows a level, for example 3 of 10.
function W.dots(props: { [string]: any }, count: number, color: Color3): (Frame, (number) -> ())
	local p = table.clone(props)
	p.BackgroundTransparency = 1
	p.Size = p.Size or UDim2.new(1, 0, 0, 10)
	local frame = W.new("Frame", p, { W.list(4, true) })
	local dots = {}
	for i = 1, count do
		dots[i] = W.new("Frame", {
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = Theme.Line,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = frame,
		}, { W.corner(2) })
	end
	local function set(level: number)
		for i, dot in dots do
			dot.BackgroundColor3 = if i <= level then color else Theme.Line
		end
	end
	return frame, set
end

-- A short coloured uppercase tag, for example a rarity name. It has no background.
function W.chip(text: string, color: Color3, props: { [string]: any }?): TextLabel
	local p = table.clone(props or {})
	p.Text = string.upper(text)
	p.Font = Theme.FontBold
	p.TextSize = p.TextSize or Theme.TextSize.Caption
	p.TextColor3 = color
	p.TextWrapped = false
	p.Size = p.Size or UDim2.new(0, 0, 0, 16)
	p.AutomaticSize = Enum.AutomaticSize.X
	return W.label(p)
end

local CHIP_HEIGHT = 32
local STEP_BUTTON = 44

-- A row of chip buttons that wraps to more lines when it is full.
function W.chipRow(parent: Instance, order: number): Frame
	local row = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	local list = W.list(Theme.Space.S, true)
	list.Wraps = true
	list.Parent = row
	return row
end

-- A small button for a chip row. Use W.setVariant to show that it is selected.
function W.chipButton(row: Instance, text: string, onClick: () -> ()): TextButton
	local button = W.button(text, {
		variant = "quiet",
		Size = UDim2.fromOffset(0, CHIP_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = Theme.TextSize.Small,
		Parent = row,
	}, onClick)
	W.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = button })
	-- A thin outline shows that an unselected chip is a button too.
	W.stroke(Theme.Line, 1).Parent = button
	return button
end

-- A row with a title, a value, and "-" and "+" buttons. Returns a function that shows a value.
function W.stepper(parent: Instance, order: number, title: string, steps: { number }, show: (number) -> string, pick: (number) -> ()): (number) -> ()
	local row = W.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
		LayoutOrder = order,
		Parent = parent,
	})
	W.label({
		Text = title,
		TextSize = Theme.TextSize.Small,
		TextWrapped = false,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -(2 * STEP_BUTTON + 120), 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = row,
	})
	local value = W.label({
		Text = "",
		Font = Theme.FontMono,
		TextSize = Theme.TextSize.Small,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -STEP_BUTTON, 0, 0),
		Size = UDim2.new(0, 112, 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = row,
	})
	local current = steps[1]
	local function move(by: number)
		local i = table.find(steps, current) or 1
		pick(steps[math.clamp(i + by, 1, #steps)])
	end
	W.button("-", {
		Size = UDim2.new(0, STEP_BUTTON, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(STEP_BUTTON + 112), 0, 0),
		Parent = row,
	}, function()
		move(-1)
	end)
	W.button("+", {
		Size = UDim2.new(0, STEP_BUTTON, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = row,
	}, function()
		move(1)
	end)
	return function(v: number)
		current = v
		value.Text = show(v)
	end
end

-- Formats a number with commas, for example 12,500.
function W.number(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

function W.hex(color: Color3): string
	return "#" .. color:ToHex()
end

return W
