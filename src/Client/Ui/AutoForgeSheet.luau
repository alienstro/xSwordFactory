--!strict
-- The Auto forge sheet: the Stop at tier and the auto delete rules.
-- Each change sends all the rules to the server. The server cleans them and saves them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Odds = require(Shared:WaitForChild("Odds")) :: any

local Theme = require(script.Parent.Theme) :: any
local W = require(script.Parent.Widgets) :: any
local Sheet = require(script.Parent.Sheet) :: any

local AutoForgeSheet = {}

-- The server never auto deletes a sword of 1 in 1,000 or rarer (Epic and up), so the filters show only these tiers.
local FILTER_TIERS = { 1, 2, 3 }
local DAMAGE_STEPS = { 0, 10, 20, 30, 50, 75, 100, 150 }
local DELETE_SLOT_STEPS = { -1, 0, 1, 2, 3, 4, 5 }
local KEEP_SLOT_STEPS = { -1, 1, 2, 3, 4, 5 }

type Refresh = (any) -> ()

local function copy(t: any): any
	local out = {}
	for k, v in t do
		out[k] = if type(v) == "table" then copy(v) else v
	end
	return out
end

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

function AutoForgeSheet.open(ctx: any)
	Sheet.open(ctx, "Auto forge", function(body, _close)
		local refreshers: { Refresh } = {}
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		-- Each change edits a copy of the saved rules and sends it. The new state then refreshes the sheet.
		local function change(edit: (any) -> ())
			local rules = copy(ctx.state.data.autoForge)
			edit(rules)
			ctx.request("SetAutoForge", { rules = rules })
		end

		-- Stop at
		W.caption("Stop at", { LayoutOrder = nextOrder(), Parent = body })
		note(body, "Auto forge stops when it forges a sword of this tier or rarer. It also stops for each sword of 1 in 1,000 or rarer.", nextOrder())
		local stopRow = W.chipRow(body, nextOrder())
		for tier = 0, #Odds.TierNames do
			if tier ~= 1 then
				local button = W.chipButton(stopRow, if tier == 0 then "Never" else Odds.TierNames[tier], function()
					change(function(r)
						r.stopTier = tier
					end)
				end)
				table.insert(refreshers, function(r)
					W.setVariant(button, if r.stopTier == tier then "secondary" else "quiet")
				end)
			end
		end

		-- The auto delete switch
		W.caption("Auto delete", { LayoutOrder = nextOrder(), Parent = body })
		note(
			body,
			"Auto delete salvages each new sword that matches a Delete filter and no Keep filter. Keep always wins. Favorites, the equipped sword, and each sword of 1 in 1,000 or rarer stay.",
			nextOrder()
		)
		local switchRow = W.chipRow(body, nextOrder())
		local switch = W.chipButton(switchRow, "Off", function()
			change(function(r)
				r.deleteOn = not r.deleteOn
			end)
		end)
		table.insert(refreshers, function(r)
			switch.Text = if r.deleteOn then "Auto delete: on" else "Auto delete: off"
			W.setVariant(switch, if r.deleteOn then "danger" else "quiet")
		end)

		-- One filter: the Delete filter or the Keep filter.
		local function filterSection(key: string, title: string, hint: string, selected: string)
			W.divider({ LayoutOrder = nextOrder(), Parent = body })
			W.caption(title, { LayoutOrder = nextOrder(), Parent = body })
			note(body, hint, nextOrder())

			local function group(label: string, field: string, items: { { value: any, text: string } })
				note(body, label, nextOrder())
				local row = W.chipRow(body, nextOrder())
				for _, item in items do
					local button = W.chipButton(row, item.text, function()
						change(function(r)
							toggleIn(r[key][field], item.value)
						end)
					end)
					table.insert(refreshers, function(r)
						W.setVariant(button, if table.find(r[key][field], item.value) then selected else "quiet")
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
			for _, tier in FILTER_TIERS do
				table.insert(tiers, { value = tier, text = Odds.TierNames[tier] })
			end
			group("Rarity", "tiers", tiers)
			group("Material", "materials", fromDefs(Config.Materials))
			group("Durability quality", "qualities", fromDefs(Config.Qualities))
			group("Enchantment (the sword has one of them)", "enchants", fromDefs(Config.Enchants))

			local isDelete = key == "delete"
			local setSlots = W.stepper(body, nextOrder(), if isDelete then "Slots: at most" else "Slots: at least", if isDelete then DELETE_SLOT_STEPS else KEEP_SLOT_STEPS, function(v)
				return if v < 0 then "Off" else tostring(v)
			end, function(v)
				change(function(r)
					r[key].slots = v
				end)
			end)
			local setDamage = W.stepper(body, nextOrder(), if isDelete then "Damage: below" else "Damage: at least", DAMAGE_STEPS, function(v)
				return if v <= 0 then "Off" else tostring(v)
			end, function(v)
				change(function(r)
					r[key].damage = v
				end)
			end)
			table.insert(refreshers, function(r)
				setSlots(r[key].slots)
				setDamage(r[key].damage)
			end)
		end

		filterSection("delete", "Delete a new sword if it has", "Tap to select. An empty Delete filter deletes nothing.", "danger")
		filterSection("keep", "But keep it if it has", "A sword that matches one of these always stays.", "secondary")

		-- The sheet runs this after each state change.
		return function(state)
			local rules = state.data.autoForge
			if rules then
				for _, refresh in refreshers do
					refresh(rules)
				end
			end
		end
	end)
end

return AutoForgeSheet
