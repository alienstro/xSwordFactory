--!strict
-- Small helpers that make UI Instances and simple animations.

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Theme = require(script.Parent.Theme) :: any

local W = {}

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
	return W.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
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
		Thickness = thickness or 2,
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

-- A rounded panel. Its height follows its content unless `Size` has a height.
function W.card(props: { [string]: any }): Frame
	local p = table.clone(props)
	p.BackgroundColor3 = p.BackgroundColor3 or Theme.Panel
	p.BorderSizePixel = 0
	if not p.Size then
		p.Size = UDim2.new(1, 0, 0, 0)
		p.AutomaticSize = Enum.AutomaticSize.Y
	end
	return W.new("Frame", p, { W.corner(16), W.padding(14) })
end

function W.label(props: { [string]: any }): TextLabel
	local p = table.clone(props)
	p.BackgroundTransparency = p.BackgroundTransparency or 1
	p.Font = p.Font or Theme.Font
	p.TextColor3 = p.TextColor3 or Theme.Text
	p.TextSize = p.TextSize or 18
	p.TextXAlignment = p.TextXAlignment or Enum.TextXAlignment.Left
	p.TextWrapped = if p.TextWrapped == nil then true else p.TextWrapped
	p.RichText = true
	if not p.Size then
		p.Size = UDim2.new(1, 0, 0, 0)
		p.AutomaticSize = Enum.AutomaticSize.Y
	end
	return W.new("TextLabel", p)
end

local soundCache: { [string]: Sound } = {}

-- Plays a short UI sound by name from Theme.Sounds.
function W.sound(name: string, volume: number?)
	local id = Theme.Sounds[name]
	if not id then
		return
	end
	local sound = soundCache[name]
	if not sound then
		sound = W.new("Sound", { SoundId = id, Volume = volume or 0.5, Parent = SoundService })
		soundCache[name] = sound
	end
	SoundService:PlayLocalSound(sound)
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

-- Grows an object from small to full size with a small bounce.
function W.pop(obj: GuiObject, from: number?)
	local s = scaleOf(obj)
	s.Scale = from or 0.6
	W.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Moves an object a little in random directions, then puts it back.
function W.shake(obj: GuiObject, strength: number?, time: number?)
	task.spawn(function()
		local origin = obj.Position
		local amount = strength or 8
		local stop = os.clock() + (time or 0.3)
		while os.clock() < stop and obj.Parent do
			obj.Position = origin + UDim2.fromOffset(math.random(-amount, amount), math.random(-amount, amount))
			task.wait(0.03)
		end
		obj.Position = origin
	end)
end

-- Makes a button. `onClick` runs when the player clicks it.
-- Use `primary = true` for the main action: it gets the pink-orange gradient.
function W.button(text: string, props: { [string]: any }, onClick: () -> ()): TextButton
	local p = table.clone(props)
	local primary = p.primary
	p.primary = nil
	local color = if primary then Color3.new(1, 1, 1) else (p.BackgroundColor3 or Theme.Button)
	p.BackgroundColor3 = color
	p.BorderSizePixel = 0
	p.AutoButtonColor = false
	p.Font = p.Font or Theme.FontBold
	p.TextColor3 = p.TextColor3 or Theme.Text
	p.TextSize = p.TextSize or 18
	p.Text = text
	p.Size = p.Size or UDim2.new(1, 0, 0, 48)
	local button = W.new("TextButton", p, { W.corner(12) })
	if primary then
		-- A UIGradient also colours the text of its parent. So the gradient goes on a
		-- fill frame, and a label on top shows the text of the button.
		button:SetAttribute("Primary", true)
		button.BackgroundTransparency = 1
		button.TextTransparency = 1
		W.new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = button.ZIndex,
			Parent = button,
		}, { W.corner(12), W.gradient(Theme.PrimaryA, Theme.PrimaryB, 0) })
		local label = W.new("TextLabel", {
			Name = "Label",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = button.Font,
			TextSize = button.TextSize,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeTransparency = 0.7,
			TextWrapped = true,
			Text = button.Text,
			ZIndex = button.ZIndex,
			Parent = button,
		})
		button:GetPropertyChangedSignal("Text"):Connect(function()
			label.Text = button.Text
		end)
	end
	button:SetAttribute("BaseColor", color)
	local s = scaleOf(button)
	button.MouseEnter:Connect(function()
		if button.Active and not primary then
			button.BackgroundColor3 = button:GetAttribute("BaseColor"):Lerp(Color3.new(1, 1, 1), 0.12)
		end
	end)
	button.MouseLeave:Connect(function()
		if not primary then
			button.BackgroundColor3 = button:GetAttribute("BaseColor")
		end
		s.Scale = 1
	end)
	button.MouseButton1Down:Connect(function()
		if button.Active then
			W.tween(s, 0.08, { Scale = 0.95 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		W.tween(s, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.Activated:Connect(function()
		if button.Active then
			W.sound("Click", 0.3)
			onClick()
		end
	end)
	return button
end

-- Changes the colour of a button. The hover effect keeps this colour.
function W.setColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	button.BackgroundColor3 = color
end

-- Turns a button on or off. An off button is faded and does not react.
function W.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	if button:GetAttribute("Primary") then
		local fill = button:FindFirstChild("Fill") :: Frame
		local label = button:FindFirstChild("Label") :: TextLabel
		fill.BackgroundTransparency = if enabled then 0 else 0.6
		label.TextTransparency = if enabled then 0 else 0.45
		return
	end
	button.TextTransparency = if enabled then 0 else 0.45
	button.BackgroundTransparency = if enabled then 0 else 0.5
end

function W.scroll(props: { [string]: any }): ScrollingFrame
	local p = table.clone(props)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.ScrollBarThickness = 5
	p.ScrollBarImageColor3 = Theme.Muted
	p.CanvasSize = UDim2.new()
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y
	p.ScrollingDirection = Enum.ScrollingDirection.Y
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

-- A horizontal bar that shows a value from 0 to 1.
function W.bar(color: Color3, props: { [string]: any }): (Frame, (number, string) -> ())
	local p = table.clone(props)
	p.BackgroundColor3 = Color3.fromRGB(12, 9, 24)
	p.BorderSizePixel = 0
	p.Size = p.Size or UDim2.new(1, 0, 0, 24)
	local fill = W.new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, {
		W.corner(12),
		W.gradient(color:Lerp(Color3.new(1, 1, 1), 0.25), color, 90),
	})
	local text = W.label({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.FontBold,
		TextSize = 15,
		ZIndex = 2,
	})
	local frame = W.new("Frame", p, { W.corner(12), fill, text })
	local function set(ratio: number, caption: string)
		W.tween(fill, 0.25, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) })
		text.Text = caption
	end
	return frame, set
end

-- A row of dots that shows a level, for example 3 of 10.
function W.dots(props: { [string]: any }, count: number, color: Color3): (Frame, (number) -> ())
	local p = table.clone(props)
	p.BackgroundTransparency = 1
	p.Size = p.Size or UDim2.new(1, 0, 0, 14)
	local frame = W.new("Frame", p, { W.list(6, true) })
	local dots = {}
	for i = 1, count do
		dots[i] = W.new("Frame", {
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Theme.Button,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = frame,
		}, { W.corner(7) })
	end
	local function set(level: number)
		for i, dot in dots do
			dot.BackgroundColor3 = if i <= level then color else Theme.Button
		end
	end
	return frame, set
end

-- A small rounded tag, for example a rarity name.
function W.chip(text: string, color: Color3, props: { [string]: any }?): TextLabel
	local p = table.clone(props or {})
	p.Text = text
	p.Font = Theme.FontBold
	p.TextSize = p.TextSize or 14
	p.TextColor3 = Theme.Background
	p.BackgroundColor3 = color
	p.BackgroundTransparency = 0
	p.TextXAlignment = Enum.TextXAlignment.Center
	p.Size = p.Size or UDim2.new(0, 0, 0, 22)
	p.AutomaticSize = Enum.AutomaticSize.X
	local chip = W.label(p)
	W.corner(11).Parent = chip
	W.padding(10, 2).Parent = chip
	return chip
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
