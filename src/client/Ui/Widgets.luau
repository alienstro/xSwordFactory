--!strict
-- Small helpers that make UI Instances.

local Theme = require(script.Parent.Theme)

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
	return W.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function W.padding(px: number): UIPadding
	return W.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function W.list(gap: number, horizontal: boolean?): UIListLayout
	return W.new("UIListLayout", {
		Padding = UDim.new(0, gap),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function W.panel(props: { [string]: any }): Frame
	local p = table.clone(props)
	p.BackgroundColor3 = p.BackgroundColor3 or Theme.Panel
	p.BorderSizePixel = 0
	return W.new("Frame", p, { W.corner(10), W.padding(12) })
end

function W.label(props: { [string]: any }): TextLabel
	local p = table.clone(props)
	p.BackgroundTransparency = 1
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

-- Makes a button. `onClick` runs when the player clicks it.
function W.button(text: string, props: { [string]: any }, onClick: () -> ()): TextButton
	local p = table.clone(props)
	local color = p.BackgroundColor3 or Theme.Button
	p.BackgroundColor3 = color
	p.BorderSizePixel = 0
	p.AutoButtonColor = false
	p.Font = p.Font or Theme.FontBold
	p.TextColor3 = p.TextColor3 or Theme.Text
	p.TextSize = p.TextSize or 18
	p.Text = text
	p.Size = p.Size or UDim2.new(1, 0, 0, 44)
	local button = W.new("TextButton", p, { W.corner(8) })
	button:SetAttribute("BaseColor", color)
	button.MouseEnter:Connect(function()
		if button.Active then
			button.BackgroundColor3 = button:GetAttribute("BaseColor"):Lerp(Color3.new(1, 1, 1), 0.12)
		end
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = button:GetAttribute("BaseColor")
	end)
	button.Activated:Connect(function()
		if button.Active then
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

-- Turns a button on or off. An off button is grey and does not react.
function W.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.TextTransparency = if enabled then 0 else 0.5
	button.BackgroundTransparency = if enabled then 0 else 0.4
end

function W.scroll(props: { [string]: any }): ScrollingFrame
	local p = table.clone(props)
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	p.ScrollBarThickness = 6
	p.ScrollBarImageColor3 = Theme.Muted
	p.CanvasSize = UDim2.new()
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y
	p.ScrollingDirection = Enum.ScrollingDirection.Y
	return W.new("ScrollingFrame", p)
end

-- Removes all children except layouts, padding, and corners.
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
	p.BackgroundColor3 = Theme.PanelLight
	p.BorderSizePixel = 0
	p.Size = p.Size or UDim2.new(1, 0, 0, 26)
	local fill = W.new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, { W.corner(6) })
	local text = W.label({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.FontBold,
		TextSize = 16,
		ZIndex = 2,
	})
	local frame = W.new("Frame", p, { W.corner(6), fill, text })
	local function set(ratio: number, caption: string)
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		text.Text = caption
	end
	return frame, set
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
