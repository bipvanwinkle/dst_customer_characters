-- Gear upgrades for befriended clockworks. WX-78 uses Gears or Frazzled Wires on a clockwork that
-- follows him to raise its level, up to MAX_GEARS. Each level adds damage, damage reduction, health
-- and health regeneration, weighted by the kind of piece, and every Chessmaster Circuit WX-78 has
-- plugged in strengthens all of it while the clockwork follows him. Circuit sockets are the only
-- limit on that scaling, apart from a ceiling on damage reduction.

local MAX_GEARS = 5
local CIRCUIT_BONUS = 0.2 -- each Chessmaster Circuit adds this share of the per-gear values
local MAX_REDUCTION = 0.75
local KEY = "clockwork_gears"
local UPGRADE_ITEMS = { "gears", "trinket_6" } -- trinket_6 is Frazzled Wires

-- How much of each configured per-gear value a piece gets
local PIECES =
{
	bishop = { damage = 2,    reduction = 0.25, health = 0.5, regen = 0.5 }, -- glass cannon
	knight = { damage = 0.5,  reduction = 1.5,  health = 2,   regen = 1.5 }, -- tank
	rook   = { damage = 1.25, reduction = 1.25, health = 1.5, regen = 1 },   -- tank that hits hard
}
local PREFABS =
{
	knight = "knight", knight_nightmare = "knight",
	bishop = "bishop", bishop_nightmare = "bishop",
	rook = "rook", rook_nightmare = "rook",
}

local per_gear -- { damage, reduction, health, regen }, from the mod's settings

local function GetCircuits(inst)
	local leader = inst.components.follower ~= nil and inst.components.follower:GetLeader() or nil
	return leader ~= nil and leader._chess_modules or 0
end

local function Apply(inst)
	local level = inst._gear_level:value()
	local circuits = GetCircuits(inst)
	local piece = PIECES[PREFABS[inst.prefab]]
	local scale = level * (1 + CIRCUIT_BONUS * circuits)
	local health = inst.components.health

	inst.components.combat.externaldamagemultipliers:SetModifier(inst, 1 + scale * per_gear.damage * piece.damage, KEY)
	health.externalabsorbmodifiers:SetModifier(inst, math.min(MAX_REDUCTION, scale * per_gear.reduction * piece.reduction), KEY)

	local maxhealth = inst._gear_base_health + scale * per_gear.health * piece.health
	if maxhealth ~= health.maxhealth and not health:IsDead() then
		local percent = health:GetPercent()
		health:SetMaxHealth(maxhealth)
		health:SetPercent(percent)
	end

	inst._gear_regen = scale * per_gear.regen * piece.regen
	inst._gear_circuits = circuits

	if level < MAX_GEARS then
		inst:AddTag("gear_upgradable")
	else
		inst:RemoveTag("gear_upgradable")
	end
end

-- Runs on the game's own regeneration beat. The extra regeneration only flows while the base
-- game's is flowing (out of combat, after a delay), and a change in the leader's circuits is
-- picked up here since nothing announces it.
local function OnTick(inst)
	if GetCircuits(inst) ~= inst._gear_circuits then
		Apply(inst)
	end
	local health = inst.components.health
	if inst._gear_regen > 0 and inst._regen == true and health:IsHurt() and not health:IsDead() then
		health:DoDelta(inst._gear_regen, true, "regen")
	end
end

local function SetLevel(inst, level)
	inst._gear_level:set(math.clamp(level, 0, MAX_GEARS))
	Apply(inst)
	if level > 0 and inst._gear_task == nil then
		inst._gear_task = inst:DoPeriodicTask(TUNING.CLOCKWORK_HEALTH_REGEN_PERIOD, OnTick)
	end
end

local function OnDeath(inst)
	if inst.components.lootdropper ~= nil then
		for _ = 1, math.floor(inst._gear_level:value() / 2) do
			inst.components.lootdropper:SpawnLootPrefab("gears")
		end
	end
end

local function OnClockworkSpawned(inst)
	-- Synced to clients so the name can show the level
	inst._gear_level = net_tinybyte(inst.GUID, "clockwork._gear_level")

	local displaynamefn = inst.displaynamefn
	inst.displaynamefn = function(inst)
		local name = displaynamefn ~= nil and displaynamefn(inst) or STRINGS.NAMES[string.upper(inst.nameoverride or inst.prefab)]
		local level = inst._gear_level:value()
		return name ~= nil and level > 0 and (name .. " +" .. level) or name
	end

	if not TheWorld.ismastersim or inst.components.followermemory == nil then
		return
	end

	inst._gear_base_health = inst.components.health.maxhealth
	inst._gear_regen = 0
	inst._gear_circuits = 0
	inst:AddTag("gear_upgradable")
	inst:ListenForEvent("leaderchanged", Apply)
	inst:ListenForEvent("death", OnDeath)

	local OnSave, OnLoad = inst.OnSave, inst.OnLoad
	inst.OnSave = function(inst, data)
		local refs = OnSave ~= nil and OnSave(inst, data) or nil
		if inst._gear_level:value() > 0 then
			data.gear_level = inst._gear_level:value()
			-- Health above the stock maximum is cut off when the health component loads
			data.gear_health_percent = inst.components.health:GetPercent()
		end
		return refs
	end
	inst.OnLoad = function(inst, data, ...)
		if OnLoad ~= nil then
			OnLoad(inst, data, ...)
		end
		if data ~= nil and data.gear_level ~= nil then
			SetLevel(inst, data.gear_level)
			if data.gear_health_percent ~= nil and not inst.components.health:IsDead() then
				inst.components.health:SetPercent(data.gear_health_percent)
			end
		end
	end
end

-- Safe on clients: only reads tags and replicas
local function CanUpgrade(doer, target)
	if doer == nil or doer.prefab ~= "wx78" or not target:HasTag("gear_upgradable") then
		return false
	end
	local follower = target.replica.follower
	return follower ~= nil and follower:GetLeader() == doer
end

local function StopUsingItem(inst)
	inst.components.useabletargeteditem:StopUsingItem()
end

local function GetUseItemOnVerb()
	return "GEARS"
end

-- Gears already befriend a leaderless clockwork; this adds upgrading one that follows WX-78.
-- Frazzled Wires have no use on a target of their own, so upgrading is all they do.
local function OnUpgradeItemSpawned(inst)
	if inst.prefab ~= "gears" then
		inst.GetUseItemOnVerb = GetUseItemOnVerb
	end

	local ValidTarget = inst.UseableTargetedItem_ValidTarget
	inst.UseableTargetedItem_ValidTarget = function(inst, target, doer)
		return CanUpgrade(doer, target) or (ValidTarget ~= nil and ValidTarget(inst, target, doer))
	end

	if not TheWorld.ismastersim then
		return
	end

	if inst.components.useabletargeteditem == nil then
		inst:AddComponent("useabletargeteditem")
	end
	local onuse = inst.components.useabletargeteditem.onusefn
	inst.components.useabletargeteditem:SetOnUseFn(function(inst, target, doer)
		if not CanUpgrade(doer, target) then
			return onuse ~= nil and onuse(inst, target, doer)
		end
		SetLevel(target, target._gear_level:value() + 1)
		target.components.health:SetPercent(1)
		inst.components.stackable:Get():Remove()
		if inst:IsValid() then
			inst:DoStaticTaskInTime(0, StopUsingItem)
		end
		return true
	end)
end

local function init(env, config)
	per_gear = config
	for prefab in pairs(PREFABS) do
		env.AddPrefabPostInit(prefab, OnClockworkSpawned)
	end
	for _, prefab in ipairs(UPGRADE_ITEMS) do
		env.AddPrefabPostInit(prefab, OnUpgradeItemSpawned)
	end
end

return init
