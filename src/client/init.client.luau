--!strict
-- The client of Sword Factory. It draws the menu, sends the button that the
-- player clicked to the server, and draws the state that comes back.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Ui = script:WaitForChild("Ui")
local Theme = require(Ui:WaitForChild("Theme")) :: any
local W = require(Ui:WaitForChild("Widgets")) :: any
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
	BackgroundColor3 = Theme.Background,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Parent = gui,
}, { scale })
ctx.root = root

-- Small screens get a smaller UI. The root grows by the same factor so that it still fills the screen.
local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local v = camera.ViewportSize
	local s = math.clamp(math.min(v.X / 860, v.Y / 600), 0.5, 1.3)
	scale.Scale = s
	root.Size = UDim2.fromScale(1 / s, 1 / s)
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local container = W.new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromScale(1, 1),
	Parent = root,
}, {
	W.new("UISizeConstraint", { MaxSize = Vector2.new(1100, math.huge) }),
	W.padding(12),
})

-- Top bar: title, gold, and Help.
local topBar = W.panel({ Size = UDim2.new(1, 0, 0, 60), Parent = container })
W.label({
	Text = "⚔ Sword Factory",
	Font = Theme.FontBold,
	TextSize = 26,
	Size = UDim2.new(0.5, 0, 1, 0),
	Parent = topBar,
})
local goldLabel = W.label({
	Text = "",
	Font = Theme.FontBold,
	TextSize = 24,
	TextColor3 = Theme.GoldText,
	TextXAlignment = Enum.TextXAlignment.Right,
	Size = UDim2.new(0.5, -110, 1, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	Parent = topBar,
})
local helpButton = W.button("Help", {
	Size = UDim2.new(0, 90, 1, 0),
	Position = UDim2.new(1, -90, 0, 0),
	Parent = topBar,
}, function()
	Guide.start(ctx)
end)
ctx.targets.Help = helpButton

-- Tab bar and pages.
local tabBar = W.new("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 48),
	Position = UDim2.new(0, 0, 0, 70),
	Parent = container,
}, {
	W.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -6, 1, 0),
		CellPadding = UDim2.new(0, 8, 0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})
local content = W.new("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, -128),
	Position = UDim2.new(0, 0, 0, 128),
	Parent = container,
})

local tabs = {
	{ name = "Forge", module = ForgeTab },
	{ name = "Swords", module = SwordsTab },
	{ name = "Upgrades", module = UpgradesTab },
	{ name = "Fight", module = FightTab },
}
local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local views = {}

function ctx.selectTab(name: string)
	for tabName, page in pages do
		page.Visible = tabName == name
		W.setColor(tabButtons[tabName], if tabName == name then Theme.Accent else Theme.Button)
		tabButtons[tabName].TextColor3 = if tabName == name then Theme.Background else Theme.Text
	end
	ctx.currentTab = name
end

-- A short message at the bottom of the screen.
local toast = W.label({
	Text = "",
	Font = Theme.FontBold,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.new(0.8, 0, 0, 40),
	AutomaticSize = Enum.AutomaticSize.None,
	BackgroundTransparency = 0.1,
	BackgroundColor3 = Theme.PanelLight,
	Visible = false,
	ZIndex = 50,
	Parent = root,
})
toast.BackgroundTransparency = 0.1
W.corner(8).Parent = toast
local toastToken = 0
function ctx.toast(text: string, color: Color3?)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextColor3 = color or Theme.Text
	toast.Visible = true
	task.delay(2.5, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

-- A full-screen flash for a rare roll.
local flash = W.new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 100,
	Parent = gui,
})
local rareSound = W.new("Sound", {
	SoundId = "rbxasset://sounds/electronicpingshort.wav",
	Volume = 0.8,
	Parent = gui,
})
function ctx.flash(color: Color3)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.2
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	rareSound:Play()
end

local function render()
	local state = ctx.state
	if not state then
		return
	end
	goldLabel.Text = `{W.number(state.data.gold)} gold`
	for _, view in views do
		view.update(state)
	end
	Guide.update(ctx)
end

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
ctx.render = render

for i, tab in tabs do
	local page = W.new("Frame", {
		Name = tab.name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = content,
	})
	pages[tab.name] = page
	local button = W.button(tab.name, { LayoutOrder = i, Parent = tabBar }, function()
		ctx.selectTab(tab.name)
		Guide.update(ctx)
	end)
	tabButtons[tab.name] = button
	ctx.targets[tab.name .. "Tab"] = button
	views[tab.name] = tab.module.create(page, ctx)
end
ctx.selectTab("Forge")

Guide.create(ctx)

-- Wait until the server loads the data.
local loading = W.label({
	Text = "Loading your forge...",
	TextSize = 24,
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
