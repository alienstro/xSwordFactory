--!strict
-- The client of Sword Factory. It draws the menu, sends the button that the
-- player clicked to the server, and draws the state that comes back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")

local Ui = script:WaitForChild("Ui")
local Theme = require(Ui:WaitForChild("Theme")) :: any
local W = require(Ui:WaitForChild("Widgets")) :: any
local Sheet = require(Ui:WaitForChild("Sheet")) :: any
local ForgeTab = require(Ui:WaitForChild("ForgeTab")) :: any
local SwordsTab = require(Ui:WaitForChild("SwordsTab")) :: any
local UpgradesTab = require(Ui:WaitForChild("UpgradesTab")) :: any
local FightTab = require(Ui:WaitForChild("FightTab")) :: any
local Guide = require(Ui:WaitForChild("Guide")) :: any

local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Request") :: RemoteFunction

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

local TOP_HEIGHT = 68
local NAV_HEIGHT = 78

-- The shared context that each tab gets.
local ctx: any = {
	state = nil,
	targets = {}, -- name -> GuiObject, for the guide
	listeners = {}, -- functions(name, args, result) that run after each request
}

local gui = W.new("ScreenGui", {
	Name = "SwordFactory",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
ctx.gui = gui

local scale = W.new("UIScale", {})
local root = W.new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Parent = gui,
}, { scale, W.gradient(Theme.BackgroundTop, Theme.Background, 90) })
ctx.root = root

-- Small screens get a smaller UI. The root grows by the same factor so that it still fills the screen.
local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local v = camera.ViewportSize
	local s = math.clamp(math.min(v.X / 520, v.Y / 760), 0.55, 1.2)
	scale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- The top bar: title, gold pill, and Help.
local topBar = W.new("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, TOP_HEIGHT),
	Parent = root,
}, { W.padding(14, 12) })
local title = W.label({
	Text = "SWORD FACTORY",
	Font = Theme.FontDisplay,
	TextSize = 26,
	TextWrapped = false,
	TextScaled = false,
	Size = UDim2.new(1, -230, 1, 0),
	TextTruncate = Enum.TextTruncate.AtEnd,
	Parent = topBar,
})
W.gradient(Theme.Gold, Theme.PrimaryA, 0).Parent = title

local goldPill = W.new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -56, 0.5, 0),
	Size = UDim2.new(0, 0, 0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Theme.Panel,
	BorderSizePixel = 0,
	Parent = topBar,
}, { W.corner(20), W.stroke(Theme.Gold, 2), W.padding(12, 0) })
local pillList = W.list(8, true)
pillList.VerticalAlignment = Enum.VerticalAlignment.Center
pillList.Parent = goldPill
W.new("Frame", {
	Size = UDim2.fromOffset(22, 22),
	BackgroundColor3 = Theme.Gold,
	BorderSizePixel = 0,
	LayoutOrder = 1,
	Parent = goldPill,
}, {
	W.corner(11),
	W.stroke(Color3.fromRGB(200, 140, 20), 2),
	W.label({
		Text = "G",
		Font = Theme.FontDisplay,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(140, 90, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	}),
})
local goldLabel = W.label({
	Text = "0",
	Font = Theme.FontDisplay,
	TextSize = 22,
	TextColor3 = Theme.Gold,
	TextWrapped = false,
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2,
	Parent = goldPill,
})
local helpButton = W.button("?", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.fromOffset(44, 44),
	Font = Theme.FontDisplay,
	TextSize = 22,
	Parent = topBar,
}, function()
	Guide.start(ctx)
end)
helpButton:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
ctx.targets.Help = helpButton

-- The Roblox menu buttons sit in the top-left corner. Keep the title and the
-- right-side buttons inside the free part of the top bar.
local function updateTopInset()
	local ok, inset = pcall(function()
		return GuiService.TopbarInset
	end)
	local s = scale.Scale
	local left, right = 0, 0
	if ok and inset and inset.Width > 0 then
		local screenWidth = root.AbsoluteSize.X
		left = math.max(0, inset.Min.X / s - 14)
		right = math.max(0, (screenWidth - inset.Max.X) / s - 14)
	end
	title.Position = UDim2.fromOffset(left, 0)
	title.Size = UDim2.new(1, -(230 + left + right), 1, 0)
	goldPill.Position = UDim2.new(1, -(56 + right), 0.5, 0)
	helpButton.Position = UDim2.new(1, -right, 0.5, 0)
end
updateTopInset()
pcall(function()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(updateTopInset)
end)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateTopInset)

-- The page area between the top bar and the tab bar.
local content = W.new("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, -(TOP_HEIGHT + NAV_HEIGHT)),
	Position = UDim2.new(0, 0, 0, TOP_HEIGHT),
	ClipsDescendants = true,
	Parent = root,
})

-- The tab bar at the bottom, in the thumb zone.
local nav = W.new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, NAV_HEIGHT),
	BackgroundColor3 = Theme.Panel,
	BorderSizePixel = 0,
	Parent = root,
}, {
	W.padding(8, 8),
	W.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -6, 1, 0),
		CellPadding = UDim2.fromOffset(8, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local tabs = {
	{ name = "Forge", icon = "⚒️", module = ForgeTab },
	{ name = "Swords", icon = "🗡️", module = SwordsTab },
	{ name = "Upgrades", icon = "⬆️", module = UpgradesTab },
	{ name = "Fight", icon = "⚔️", module = FightTab },
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
		W.setColor(nb.button, if selected then Theme.PanelLight else Theme.Panel)
		nb.label.TextColor3 = if selected then Theme.Gold else Theme.Muted
		if selected then
			W.pop(nb.icon, 0.7)
		end
	end
	Sheet.close()
end

-- A short message above the tab bar.
local toast = W.label({
	Text = "",
	Font = Theme.FontBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -(NAV_HEIGHT + 14)),
	Size = UDim2.new(0, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 0,
	BackgroundColor3 = Theme.PanelLight,
	Visible = false,
	ZIndex = 80,
	Parent = root,
})
W.corner(18).Parent = toast
W.padding(16, 10).Parent = toast
W.new("UISizeConstraint", { MaxSize = Vector2.new(460, math.huge), Parent = toast })
local toastStroke = W.stroke(Theme.Button, 2)
toastStroke.Parent = toast
local toastToken = 0
function ctx.toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextColor3 = color or Theme.Text
	toastStroke.Color = color or Theme.Button
	toast.Visible = true
	W.pop(toast, 0.8)
	task.delay(2.4, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

-- Shows "+15" or "-25" that floats down from the gold pill.
local lastGold: number? = nil
local function showGoldChange(gold: number)
	if lastGold and gold ~= lastGold then
		local diff = gold - lastGold
		local float = W.label({
			Text = (if diff > 0 then "+" else "-") .. W.number(math.abs(diff)),
			Font = Theme.FontDisplay,
			TextSize = 20,
			TextColor3 = if diff > 0 then Theme.Good else Theme.Bad,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -70, 0, TOP_HEIGHT - 8),
			Size = UDim2.fromOffset(120, 24),
			ZIndex = 85,
			Parent = root,
		})
		W.tween(float, 0.9, { Position = float.Position + UDim2.fromOffset(0, 26), TextTransparency = 1 })
		task.delay(1, function()
			float:Destroy()
		end)
		W.pop(goldPill, 0.9)
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

	local button = W.button("", { LayoutOrder = i, BackgroundColor3 = Theme.Panel, Parent = nav }, function()
		ctx.selectTab(tab.name)
		Guide.update(ctx)
	end)
	button.Name = tab.name .. "Tab"
	local icon = W.label({
		Text = tab.icon,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 4),
		Parent = button,
	})
	local label = W.label({
		Text = tab.name,
		Font = Theme.FontBold,
		TextSize = 14,
		TextColor3 = Theme.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 38),
		Parent = button,
	})
	navButtons[tab.name] = { button = button, label = label, icon = icon }
	ctx.targets[tab.name .. "Tab"] = button
	views[tab.name] = tab.module.create(page, ctx)
end
ctx.selectTab("Forge")

Guide.create(ctx)

-- Wait until the server loads the data.
local loading = W.label({
	Text = "Loading your forge...",
	Font = Theme.FontDisplay,
	TextSize = 26,
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
