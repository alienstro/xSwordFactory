--!strict
-- The client of Sword Factory. It draws the menu, sends the button that the
-- player clicked to the server, and draws the state that comes back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Ui = script:WaitForChild("Ui")
local Theme = require(Ui:WaitForChild("Theme")) :: any
local W = require(Ui:WaitForChild("Widgets")) :: any
local Sheet = require(Ui:WaitForChild("Sheet")) :: any
local ForgeTab = require(Ui:WaitForChild("ForgeTab")) :: any
local SwordsTab = require(Ui:WaitForChild("SwordsTab")) :: any
local UpgradesTab = require(Ui:WaitForChild("UpgradesTab")) :: any
local FightTab = require(Ui:WaitForChild("FightTab")) :: any
local Guide = require(Ui:WaitForChild("Guide")) :: any
local Settings = require(Ui:WaitForChild("Settings")) :: any

local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Request") :: RemoteFunction

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local TOP_HEIGHT = 56
local NAV_HEIGHT = 56

-- The shared context that each tab gets.
local ctx: any = {
	state = nil,
	targets = {}, -- name -> GuiObject, for the guide
	listeners = {}, -- functions(name, args, result) that run after each request
	navHeight = NAV_HEIGHT,
}

local playerGui = player:WaitForChild("PlayerGui")

-- The backdrop fills the whole screen, also behind the Roblox top bar and the notch.
local backdrop = W.new("ScreenGui", {
	Name = "SwordFactoryBackdrop",
	ScreenInsets = Enum.ScreenInsets.None,
	ResetOnSpawn = false,
	DisplayOrder = 0,
	Parent = playerGui,
})
W.new("Frame", {
	Name = "Fill",
	BackgroundColor3 = Theme.Background,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Parent = backdrop,
})
-- Overlays use this rectangle to cover the full screen.
ctx.fullScreen = backdrop

-- The menu stays inside the area that the Roblox buttons and the notch do not cover.
local gui = W.new("ScreenGui", {
	Name = "SwordFactory",
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 1,
	Parent = playerGui,
})
ctx.gui = gui

local scale = W.new("UIScale", {})
local root = W.new("Frame", {
	Name = "Root",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Parent = gui,
}, { scale })
ctx.root = root
W.preloadSounds()

-- Small screens get a smaller UI. The root grows by the same factor so that it still fills the screen.
local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local v = camera.ViewportSize
	local s = math.clamp(math.min(v.X / 480, v.Y / 720), 0.6, 1.15)
	scale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- The header shares the content column: title on the left, gold and Guide on the right.
local header = W.new("Frame", {
	Name = "Header",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, -2 * Theme.Space.L, 0, TOP_HEIGHT),
	BackgroundTransparency = 1,
	Parent = root,
}, { W.maxWidth(Theme.ColumnWidth) })
W.label({
	Name = "Title",
	Text = "SWORD FACTORY",
	Font = Theme.FontDisplay,
	TextSize = Theme.TextSize.Title,
	TextColor3 = Theme.Text,
	TextWrapped = false,
	TextYAlignment = Enum.TextYAlignment.Center,
	Size = UDim2.new(0.5, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.None,
	Parent = header,
})

local right = W.new("Frame", {
	Name = "Wallet",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromScale(1, 0.5),
	Size = UDim2.new(0, 0, 0, Theme.ControlHeight),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Parent = header,
})
local rightList = W.list(Theme.Space.M, true)
rightList.VerticalAlignment = Enum.VerticalAlignment.Center
rightList.Parent = right

local goldLabel = W.label({
	Name = "Gold",
	Text = "0",
	Font = Theme.FontMono,
	TextSize = Theme.TextSize.Lead,
	TextColor3 = Theme.Gold,
	TextWrapped = false,
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	TextYAlignment = Enum.TextYAlignment.Center,
	LayoutOrder = 1,
	Parent = right,
})
W.caption("gold", {
	Name = "GoldCaption",
	TextColor3 = Theme.Faint,
	TextWrapped = false,
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	TextYAlignment = Enum.TextYAlignment.Center,
	LayoutOrder = 2,
	Parent = right,
})
local helpButton = W.button("Guide", {
	Name = "GuideButton",
	variant = "quiet",
	Size = UDim2.fromOffset(72, 36),
	TextSize = Theme.TextSize.Small,
	LayoutOrder = 3,
	Parent = right,
}, function()
	Guide.start(ctx)
end)
ctx.targets.Help = helpButton
W.button("Settings", {
	Name = "SettingsButton",
	variant = "quiet",
	Size = UDim2.fromOffset(84, 36),
	TextSize = Theme.TextSize.Small,
	LayoutOrder = 4,
	Parent = right,
}, function()
	Settings.open(ctx)
end)

-- The page area between the header and the tab bar.
local content = W.new("Frame", {
	Name = "Pages",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, -(TOP_HEIGHT + NAV_HEIGHT)),
	Position = UDim2.new(0, 0, 0, TOP_HEIGHT),
	ClipsDescendants = true,
	Parent = root,
})

-- The tab bar at the bottom, in the thumb zone. A line on top separates it from the page.
local nav = W.new("Frame", {
	Name = "TabBar",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, NAV_HEIGHT),
	BackgroundColor3 = Theme.Surface,
	BorderSizePixel = 0,
	Parent = root,
})
W.divider({ Name = "TopLine", Parent = nav })
local navRow = W.new("Frame", {
	Name = "Tabs",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, -2 * Theme.Space.L, 1, 0),
	BackgroundTransparency = 1,
	Parent = nav,
}, {
	W.maxWidth(Theme.ColumnWidth),
	W.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, 0, 1, 0),
		CellPadding = UDim2.fromOffset(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local tabs = {
	{ name = "Forge", module = ForgeTab },
	{ name = "Swords", module = SwordsTab },
	{ name = "Upgrades", module = UpgradesTab },
	{ name = "Fight", module = FightTab },
}
local pages: { [string]: Frame } = {}
local navButtons: { [string]: any } = {}
local views = {}

function ctx.selectTab(name: string)
	if ctx.currentTab == name then
		return
	end
	ctx.currentTab = name
	for tabName, page in pages do
		local selected = tabName == name
		page.Visible = selected
		local nb = navButtons[tabName]
		nb.button:SetAttribute("TextColor", if selected then Theme.Text else Theme.Muted)
		W.setEnabled(nb.button, true)
		nb.button.Font = if selected then Theme.FontBold else Theme.FontMedium
		nb.indicator.Visible = selected
	end
	Sheet.close()
end

-- A short message above the tab bar.
local toast = W.label({
	Name = "Toast",
	Text = "",
	Font = Theme.FontMedium,
	TextSize = Theme.TextSize.Body,
	TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -(NAV_HEIGHT + Theme.Space.M)),
	Size = UDim2.new(0, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 0,
	BackgroundColor3 = Theme.Raised,
	Visible = false,
	ZIndex = 80,
	Parent = root,
})
W.corner(Theme.Radius.Control).Parent = toast
W.padding(Theme.Space.L, Theme.Space.S + 2).Parent = toast
W.new("UISizeConstraint", { MaxSize = Vector2.new(440, math.huge), Parent = toast })
local toastToken = 0
function ctx.toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextColor3 = color or Theme.Text
	toast.Visible = true
	W.pop(toast, 0.9)
	task.delay(2.4, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

-- Shows "+15" or "-25" under the gold amount for a moment.
local lastGold: number? = nil
local function showGoldChange(gold: number)
	if lastGold and gold ~= lastGold and not W.reducedMotion() then
		local diff = gold - lastGold
		local float = W.label({
			Text = (if diff > 0 then "+" else "-") .. W.number(math.abs(diff)),
			Font = Theme.FontMono,
			TextSize = Theme.TextSize.Small,
			TextColor3 = if diff > 0 then Theme.Good else Theme.Bad,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(0, goldLabel.AbsolutePosition.X - header.AbsolutePosition.X, 1, -8),
			Size = UDim2.fromOffset(goldLabel.AbsoluteSize.X, 18),
			ZIndex = 85,
			Parent = header,
		})
		W.tween(float, 0.8, { Position = float.Position + UDim2.fromOffset(0, 10), TextTransparency = 1 })
		task.delay(0.9, function()
			float:Destroy()
		end)
	end
	lastGold = gold
end

local function render()
	local state = ctx.state
	if not state then
		return
	end
	goldLabel.Text = W.number(state.data.gold)
	showGoldChange(state.data.gold)
	Settings.apply(state)
	for _, view in views do
		view.update(state)
	end
	Sheet.update(state)
	Guide.update(ctx)
end
ctx.render = render

-- Sends one button to the server. Returns the result. Never throws.
function ctx.request(name: string, args: { [string]: any }?): any
	local ok, response = pcall(function()
		return request:InvokeServer(name, args or {})
	end)
	if not ok or type(response) ~= "table" then
		ctx.toast("The server did not answer. Try again.", Theme.Bad)
		return { ok = false, err = "No answer." }
	end
	if response.state then
		ctx.state = response.state
	end
	local result = response.result or { ok = false }
	if not result.ok and result.err then
		ctx.toast(result.err, Theme.Bad)
	end
	for _, listener in ctx.listeners do
		task.spawn(listener, name, args or {}, result)
	end
	render()
	return result
end

for i, tab in tabs do
	local page = W.new("Frame", {
		Name = tab.name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = content,
	})
	pages[tab.name] = page

	local button = W.button(tab.name, {
		Name = tab.name .. "Tab",
		variant = "quiet",
		LayoutOrder = i,
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.TextSize.Body,
		Parent = navRow,
	}, function()
		ctx.selectTab(tab.name)
		Guide.update(ctx)
	end)
	button:FindFirstChildOfClass("UICorner"):Destroy()
	local indicator = W.new("Frame", {
		Name = "Indicator",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0.5, 0, 0, 2),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Visible = false,
		Parent = button,
	})
	navButtons[tab.name] = { button = button, indicator = indicator }
	ctx.targets[tab.name .. "Tab"] = button
	views[tab.name] = tab.module.create(page, ctx)
end
ctx.selectTab("Forge")

Guide.create(ctx)

-- Wait until the server loads the data.
local loading = W.label({
	Name = "Loading",
	Text = "LOADING YOUR FORGE",
	Font = Theme.FontDisplay,
	TextSize = Theme.TextSize.Title,
	TextColor3 = Theme.Muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 0,
	BackgroundColor3 = Theme.Background,
	ZIndex = 90,
	Parent = root,
})
while true do
	local ok, response = pcall(function()
		return request:InvokeServer("GetState", {})
	end)
	if ok and type(response) == "table" and response.state then
		ctx.state = response.state
		break
	end
	task.wait(1)
end
loading:Destroy()
render()
if not ctx.state.data.guideDone then
	Guide.start(ctx)
end
