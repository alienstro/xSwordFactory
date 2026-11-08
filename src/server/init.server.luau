--!strict
-- The server of Sword Factory. It owns all game state, runs all rolls,
-- and saves the data with ProfileStore. The client only sends button names.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Actions = require(Shared:WaitForChild("Actions")) :: any
local Config = require(Shared:WaitForChild("Config")) :: any
local RateLimit = require(Shared:WaitForChild("RateLimit")) :: any
local ProfileStore = require(script:WaitForChild("ProfileStore")) :: any

local STORE_NAME = "PlayerData_v1"

-- The game uses only the menu. No player character spawns.
Players.CharacterAutoLoads = false

local store = ProfileStore.New(STORE_NAME, Actions.newData())
local rng = Random.new()

type PlayerState = { profile: any, session: any, bucket: any }
local players: { [Player]: PlayerState } = {}

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local request = Instance.new("RemoteFunction")
request.Name = "Request"
request.Parent = remotes
remotes.Parent = ReplicatedStorage

local function snapshot(state: PlayerState)
	return { data = state.profile.Data, fight = state.session.fight }
end

request.OnServerInvoke = function(player: Player, name: any, args: any)
	local state = players[player]
	if not state then
		return { result = { ok = false, err = "Your data is loading." } }
	end
	if not RateLimit.allow(state.bucket, os.clock()) then
		return { result = { ok = false, err = "Too many clicks. Wait a moment." }, state = snapshot(state) }
	end
	if name == "GetState" then
		return { result = { ok = true }, state = snapshot(state) }
	end

	local ok, result = pcall(Actions.run, state.profile.Data, state.session, name, args, rng)
	if not ok then
		warn(`[SwordFactory] action {tostring(name)} failed for {player.Name}: {result}`)
		result = { ok = false, err = "Something went wrong." }
	end
	return { result = result, state = snapshot(state) }
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Your data did not load. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		players[player] = nil
		player:Kick("Your data was opened on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	players[player] = {
		profile = profile,
		session = Actions.newSession(),
		bucket = RateLimit.new(Config.RequestRate, Config.RequestBurst),
	}
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	local state = players[player]
	if state then
		players[player] = nil
		state.profile:EndSession()
	end
end)
