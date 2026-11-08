--!strict
-- The Filter sheet of the Swords tab: the sort and the filter groups.
-- The filter is a client view only. It does not go to the server and it resets when the player joins again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Odds = require(Shared:WaitForChild("Odds")) :: any
local SwordFilter = require(Shared:WaitForChild("SwordFilter")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any
local Sheet = require(script.Parent.Sheet) :: any

local SwordFilterSheet = {}

local DAMAGE_STEPS = { 0, 10, 20, 30, 50, 75, 100, 150 }
local SLOT_STEPS = { 0, 1, 2, 3, 4, 5 }

-- The view state that the Swords tab keeps.
export type View = { filter: any, sort: string }

local function toggleIn(list: { any }, value: any)
	local i = table.find(list, value)
	if i then
		table.remove(list, i)
	else
		table.insert(list, value)
	end
end

local function note(parent: Instance, text: string, order: number)
	W.label({ Text = text, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Muted, LayoutOrder = order, Parent = parent })
end

function SwordFilterSheet.open(ctx: any, view: View)
	Sheet.open(ctx, "Filter swords", function(body, close)
		local refreshers: { (any) -> () } = {}
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		-- Each change edits the view, then ctx.render() updates the list and this sheet.
		local function change(edit: () -> ())
			edit()
			ctx.render()
		end

		-- The sort
		W.caption("Sort by", { LayoutOrder = nextOrder(), Parent = body })
		local sortRow = W.chipRow(body, nextOrder())
		for _, sort in SwordFilter.Sorts do
			local button = W.chipButton(sortRow, SwordFilter.SortNames[sort], function()
				change(function()
					view.sort = sort
				end)
			end)
			table.insert(refreshers, function()
				W.setVariant(button, if view.sort == sort then "secondary" else "quiet")
			end)
		end

		-- The filter groups
		W.divider({ LayoutOrder = nextOrder(), Parent = body })
		W.caption("Show only swords with", { LayoutOrder = nextOrder(), Parent = body })
		note(body, "Tap to select. In one group, a sword needs one of the selected values. A sword needs a match in each group that you use.", nextOrder())

		local favRow = W.chipRow(body, nextOrder())
		local favButton = W.chipButton(favRow, "Favorites only", function()
			change(function()
				view.filter.favoritesOnly = not view.filter.favoritesOnly
			end)
		end)
		table.insert(refreshers, function()
			W.setVariant(favButton, if view.filter.favoritesOnly then "secondary" else "quiet")
		end)

		local function group(label: string, field: string, items: { { value: any, text: string } })
			note(body, label, nextOrder())
			local row = W.chipRow(body, nextOrder())
			for _, item in items do
				local button = W.chipButton(row, item.text, function()
					change(function()
						toggleIn(view.filter[field], item.value)
					end)
				end)
				table.insert(refreshers, function()
					W.setVariant(button, if table.find(view.filter[field], item.value) then "secondary" else "quiet")
				end)
			end
		end
		local function fromDefs(defs: { any }): { { value: any, text: string } }
			local items = {}
			for _, def in defs do
				table.insert(items, { value = def.id, text = def.name })
			end
			return items
		end
		local tiers = {}
		for tier, name in Odds.TierNames do
			table.insert(tiers, { value = tier, text = name })
		end
		group("Rarity", "tiers", tiers)
		group("Material", "materials", fromDefs(Config.Materials))
		group("Durability quality", "qualities", fromDefs(Config.Qualities))
		group("Enchantment", "enchants", fromDefs(Config.Enchants))

		local setDamage = W.stepper(body, nextOrder(), "Damage: at least", DAMAGE_STEPS, function(v)
			return if v <= 0 then "Off" else tostring(v)
		end, function(v)
			change(function()
				view.filter.minDamage = v
			end)
		end)
		local setSlots = W.stepper(body, nextOrder(), "Slots: at least", SLOT_STEPS, function(v)
			return if v <= 0 then "Off" else tostring(v)
		end, function(v)
			change(function()
				view.filter.minSlots = v
			end)
		end)
		table.insert(refreshers, function()
			setDamage(view.filter.minDamage)
			setSlots(view.filter.minSlots)
		end)

		-- The result count and the two actions
		W.divider({ LayoutOrder = nextOrder(), Parent = body })
		local result = W.label({ Text = "", TextSize = Theme.TextSize.Small, TextColor3 = Theme.Muted, LayoutOrder = nextOrder(), Parent = body })
		local actions = W.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
			LayoutOrder = nextOrder(),
			Parent = body,
		}, {
			W.new("UIGridLayout", {
				CellSize = UDim2.new(0.5, -4, 1, 0),
				CellPadding = UDim2.fromOffset(8, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local clear = W.button("Clear filter", { variant = "quiet", LayoutOrder = 1, Parent = actions }, function()
			change(function()
				view.filter = SwordFilter.new()
			end)
		end)
		W.button("Done", { variant = "primary", LayoutOrder = 2, Parent = actions }, close)

		return function(state)
			for _, refresh in refreshers do
				refresh(state)
			end
			local swords = state.data.swords
			local shown = #SwordFilter.apply(swords, view.filter, view.sort, state.data.equipped)
			result.Text = `Showing <b>{shown}</b> of {Odds.plural(#swords, "sword")}.`
			W.setEnabled(clear, SwordFilter.activeCount(view.filter) > 0)
		end
	end)
end

return SwordFilterSheet
