-- Befriended clockworks travel between the surface and the caves with their leader.
--
-- The game releases a survivor's followers when they leave a shard, so clockworks stay behind and
-- wait for them to come back. Here the clockworks following a survivor are saved into the survivor's
-- own record as they leave, as pets are, and spawned from it where they arrive. Clockworks parked
-- by the Conductor's Whistle have no leader, so they stay where they are.

-- Save every clockwork following this player and take it out of the world
local function Pack(player)
	local clockworks = {}
	for follower in pairs(player.components.leader.followers) do
		if follower.TryBefriendChess ~= nil and follower.components.followermemory ~= nil
			and not follower.components.health:IsDead() then
			table.insert(clockworks, follower)
		end
	end
	local records = {}
	for _, clockwork in ipairs(clockworks) do
		table.insert(records, (clockwork:GetSaveRecord()))
		clockwork:Remove()
	end
	return #records > 0 and records or nil
end

-- Goes through the game's own befriending, so the limit on followers still applies
local function Rejoin(clockwork, player)
	if not clockwork:IsValid() then
		return
	end
	if not (player:IsValid() and clockwork:TryBefriendChess(player)) then
		-- No room for it, or the survivor arrived as a ghost. It waits here as any clockwork without
		-- its leader does, and the home it loaded with is a place on the other shard.
		clockwork.components.knownlocations:RememberLocation("home", clockwork:GetPosition())
	end
end

local function Unpack(player, records)
	for _, record in ipairs(records) do
		local clockwork = SpawnSaveRecord(record)
		if clockwork ~= nil then
			-- The follower component would otherwise rejoin by itself, past the limit on followers
			clockwork.components.follower:ClearCachedPlayerLeader()
			-- The game moves these to wherever the player comes out. After a failed trip there is
			-- nowhere to move them, and they stay where they were saved.
			if player.migrationpets ~= nil then
				table.insert(player.migrationpets, clockwork)
			end
			-- Wait for the player and the clockwork to be placed
			clockwork:DoTaskInTime(0, Rejoin, player)
		end
	end
end

local function OnPlayerSpawned(inst)
	if not TheWorld.ismastersim then
		return
	end

	local OnDespawn, OnSave, OnLoad = inst.OnDespawn, inst.OnSave, inst.OnLoad
	-- Runs before the game releases the player's followers
	inst.OnDespawn = function(inst, migrationdata, ...)
		if migrationdata ~= nil then
			inst._migrating_clockworks = Pack(inst)
		end
		return OnDespawn(inst, migrationdata, ...)
	end
	inst.OnSave = function(inst, data, ...)
		data.migrating_clockworks = inst._migrating_clockworks
		return OnSave(inst, data, ...)
	end
	inst.OnLoad = function(inst, data, ...)
		OnLoad(inst, data, ...)
		if data ~= nil and data.migrating_clockworks ~= nil then
			Unpack(inst, data.migrating_clockworks)
		end
	end
end

local function init(env)
	env.AddPlayerPostInit(OnPlayerSpawned)
end

return init
