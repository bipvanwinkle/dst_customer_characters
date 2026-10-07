-- Parking for befriended clockworks, used by the Conductor's Whistle.
--
-- The game already has a state for a clockwork whose leader is gone: it settles where it stands,
-- treats that spot as home, only fights back when attacked, and remembers its leader so it can
-- rejoin when they come near. Parking puts a clockwork in that state and holds off the rejoin.

local CLOCKWORKS = { "knight", "bishop", "rook", "knight_nightmare", "bishop_nightmare", "rook_nightmare" }
local RETURN_DIST = 30

local parked = {} -- every parked clockwork on this shard

local function SetParked(inst, value)
	inst._whistle_parked = value or nil
	parked[inst] = value or nil
end

-- Park every clockwork following this player
local function Park(player)
	if player.components.leader == nil then
		return
	end
	local clockworks = {}
	for follower in pairs(player.components.leader.followers) do
		if follower.TryBefriendChess ~= nil and follower.components.followermemory ~= nil then
			table.insert(clockworks, follower)
		end
	end
	for _, clockwork in ipairs(clockworks) do
		SetParked(clockwork, true)
		clockwork.components.follower:SetLeader(nil)
	end
end

-- Send every clockwork this player parked back to them, from wherever it is on this shard. Any that
-- the player has no room for stay parked.
local function Unpark(player)
	local clockworks = {}
	for clockwork in pairs(parked) do
		if clockwork:IsValid() and clockwork.components.followermemory:IsRememberedLeader(player) then
			table.insert(clockworks, clockwork)
		end
	end
	local pos = player:GetPosition()
	for _, clockwork in ipairs(clockworks) do
		SetParked(clockwork, false)
		if not clockwork:TryBefriendChess(player) then
			SetParked(clockwork, true)
		elseif not clockwork:IsNear(player, RETURN_DIST) then
			local offset = FindWalkableOffset(pos, math.random() * TWOPI, 4, 12, true) or Vector3(0, 0, 0)
			clockwork.Physics:Teleport(pos.x + offset.x, 0, pos.z + offset.z)
		end
	end
end

local function OnClockworkSpawned(inst)
	if not TheWorld.ismastersim or inst.components.followermemory == nil then
		return
	end

	-- Hold off the automatic rejoin while parked. Gears still work on a parked clockwork, since
	-- that goes through inst.TryBefriendChess directly.
	local reunite = inst.components.followermemory.onreuniteleaderfn
	inst.components.followermemory:SetOnReuniteLeaderFn(function(inst, player)
		if inst._whistle_parked then
			return false
		end
		return reunite ~= nil and reunite(inst, player)
	end)

	inst:ListenForEvent("leaderchanged", function(inst, data)
		if data ~= nil and data.new ~= nil then
			SetParked(inst, false)
		end
	end)
	inst:ListenForEvent("onremove", function(inst)
		parked[inst] = nil
	end)

	local OnSave, OnLoad = inst.OnSave, inst.OnLoad
	inst.OnSave = function(inst, data)
		local refs = OnSave ~= nil and OnSave(inst, data) or nil
		data.whistle_parked = inst._whistle_parked
		return refs
	end
	inst.OnLoad = function(inst, data, ...)
		if OnLoad ~= nil then
			OnLoad(inst, data, ...)
		end
		if data ~= nil and data.whistle_parked then
			SetParked(inst, true)
		end
	end
end

local function init(env)
	for _, prefab in ipairs(CLOCKWORKS) do
		env.AddPrefabPostInit(prefab, OnClockworkSpawned)
	end
end

return { init = init, Park = Park, Unpark = Unpark }
