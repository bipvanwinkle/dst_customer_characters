-- Beefalo charge: while riding a beefalo, the same press that makes the weremoose charge sends the
-- beefalo charging. It follows the weremoose's charge in SGwilson (tackle_pre, tackle_start, tackle,
-- tackle_collide, tackle_stop) and uses the same tackler component for collisions: creatures in the
-- way are hit and run through, while trees, boulders and walls stop the charge.
--
-- What differs from the weremoose:
--   * riding animations stand in for the weremoose's charge drawings, so durations are fixed
--     rather than read from animation lengths
--   * trees and boulders take half the work, and structures are not hammered
--   * hits deal the beefalo's damage, whatever the rider is holding
--   * a collision does not leave the rider groggy

local CHARGE_SPEED = TUNING.WEREMOOSE_TACKLE_SPEED
local CHARGE_TIME = 1.6
local PRE_TIME = 6 * FRAMES

-- Works on the server and on clients. Walter's Woby is ridden too, but does not charge.
local function IsRidingBeefalo(inst)
	local rider = inst.replica.rider
	if rider == nil or not rider:IsRiding() then
		return false
	end
	local mount = rider:GetMount()
	return mount == nil or mount:HasTag("beefalo")
end

-- The player's own game knows from its predicted state; otherwise the tag the server shares says so
local function IsMoving(inst)
	return (inst.sg ~= nil and inst.sg:HasStateTag("moving")) or inst:HasTag("moving")
end

local function PlayMountSound(inst, sound)
	local mount = inst.components.rider ~= nil and inst.components.rider:GetMount() or nil
	if mount ~= nil and mount.sounds ~= nil and mount.sounds[sound] ~= nil then
		inst.SoundEmitter:PlaySound(mount.sounds[sound])
	end
end

local function SpawnFxAt(prefab, x, z)
	local fx = SpawnPrefab(prefab)
	if fx ~= nil then
		fx.Transform:SetPosition(x, 0, z)
	end
	return fx
end

local function OnCollide(inst, other)
	local x, y, z = inst.Transform:GetWorldPosition()
	local x1, y1, z1 = other.Transform:GetWorldPosition()
	local r = other:GetPhysicsRadius(.5)
	r = r / (r + 1)
	SpawnFxAt("round_puff_fx_hi", x1 + (x - x1) * r, z1 + (z - z1) * r)
	inst.SoundEmitter:PlaySound("dontstarve/characters/woodie/moose/bounce")
	ShakeAllCameras(CAMERASHAKE.FULL, .6, .025, .4, other, 20)
end

local function OnTrample(inst, other)
	local x, y, z = other.Transform:GetWorldPosition()
	SpawnFxAt((other:HasTag("largecreature") or other:HasTag("epic")) and "round_puff_fx_lg" or "round_puff_fx_sm", x, z)
end

-- The tackler is added for the length of a charge and removed after, so it never lingers on Woodie,
-- who adds and removes his own when he changes into and out of the weremoose.
local function StartCharge(inst)
	if inst.components.tackler == nil then
		inst:AddComponent("tackler")
	end
	local tackler = inst.components.tackler
	tackler:SetDistance(.5)
	tackler:SetRadius(.75)
	tackler:SetStructureDamageMultiplier(1)
	tackler.work_actions = {}
	tackler:AddWorkAction(ACTIONS.CHOP, 4)
	tackler:AddWorkAction(ACTIONS.MINE, 2)
	tackler:SetOnCollideFn(OnCollide)
	tackler:SetOnTrampleFn(OnTrample)
	tackler:SetEdgeDistance(5)
	-- With no weapon, a riding attack deals the mount's damage
	inst.components.combat.GetWeapon = function() return nil end
end

local function EndCharge(inst)
	inst.components.combat.GetWeapon = nil
	if inst.components.tackler ~= nil then
		inst:RemoveComponent("tackler")
	end
end

local function SpawnTrail(inst, data)
	if data.delay > 0 then
		data.delay = data.delay - 1
		return
	end
	data.delay = math.random(4, 6)
	local x, y, z = inst.Transform:GetWorldPosition()
	local angle = inst.Transform:GetRotation() * DEGREES
	local fx = SpawnFxAt("plant_dug_small_fx", x - math.cos(angle) * 1.6, z + math.sin(angle) * 1.6)
	if fx ~= nil then
		if math.random() < .5 then
			fx.AnimState:SetScale(-1, 1)
		end
		local scale = .8 + math.random() * .5
		fx.Transform:SetScale(scale, scale, scale)
	end
	inst.SoundEmitter:PlaySound("dontstarve/beefalo/walk")
end

local states =
{
	State{
		name = "beefalo_charge_pre",
		tags = { "busy" },

		onenter = function(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("run_pre")
			inst:ShowActions(false)
			inst.sg:SetTimeout(PRE_TIME)
		end,

		ontimeout = function(inst)
			inst:PerformBufferedAction()
			if inst.sg.currentstate.name == "beefalo_charge_pre" then
				--action failed, charge anyway, as the weremoose does
				inst.sg.statemem.charging = true
				inst.sg:GoToState("beefalo_charge")
			end
		end,

		onexit = function(inst)
			if not inst.sg.statemem.charging then
				inst:ShowActions(true)
			end
		end,
	},

	State{
		name = "beefalo_charge",
		tags = { "busy", "nopredict", "nomorph", "nointerrupt", "canelectrocute" },

		onenter = function(inst)
			if not IsRidingBeefalo(inst) then
				inst.sg:GoToState("idle")
				return
			end
			StartCharge(inst)
			inst.components.locomotor:Stop()
			inst.AnimState:PlayAnimation("run_loop", true)
			inst.Physics:SetMotorVel(CHARGE_SPEED, 0, 0)
			inst.Physics:ClearCollidesWith(COLLISION.CHARACTERS)
			PlayMountSound(inst, "angry")
			inst.sg.statemem.targets = {}
			inst.sg.statemem.edgecount = 0
			inst.sg.statemem.trailtask = inst:DoPeriodicTask(0, SpawnTrail, nil, { delay = 0 })
			inst.sg:SetTimeout(CHARGE_TIME)
		end,

		onupdate = function(inst)
			if inst.components.tackler == nil or not IsRidingBeefalo(inst) then
				inst.sg:GoToState("idle")
			elseif inst.components.tackler:CheckCollision(inst.sg.statemem.targets) then
				inst.sg.statemem.stopping = true
				inst.sg:GoToState("beefalo_charge_collide")
			elseif not inst.components.tackler:CheckEdge() then
				inst.sg.statemem.edgecount = 0
			elseif inst.sg.statemem.edgecount < 3 then
				inst.sg.statemem.edgecount = inst.sg.statemem.edgecount + 1
			else
				inst.sg.statemem.stopping = true
				inst.sg:GoToState("beefalo_charge_stop")
			end
		end,

		ontimeout = function(inst)
			inst.sg.statemem.stopping = true
			inst.sg:GoToState("beefalo_charge_stop")
		end,

		onexit = function(inst)
			if inst.sg.statemem.trailtask ~= nil then
				inst.sg.statemem.trailtask:Cancel()
				inst.sg.statemem.trailtask = nil
			end
			EndCharge(inst)
			inst.Physics:Stop()
			inst.Physics:CollidesWith(COLLISION.CHARACTERS)
			inst.Physics:Teleport(inst.Transform:GetWorldPosition())
			if not inst.sg.statemem.stopping then
				inst:ShowActions(true)
			end
		end,
	},

	State{
		name = "beefalo_charge_collide",
		tags = { "busy", "nopredict", "nomorph", "nointerrupt", "canelectrocute" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("hit")
			PlayMountSound(inst, "grunt")
		end,

		timeline =
		{
			TimeEvent(8.5 * FRAMES, function(inst)
				inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
			end),
			TimeEvent(12 * FRAMES, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			TimeEvent(15 * FRAMES, function(inst)
				inst.sg:GoToState("idle", true)
			end),
		},

		onexit = function(inst)
			inst:ShowActions(true)
		end,
	},

	State{
		name = "beefalo_charge_stop",
		tags = { "busy", "nopredict", "nomorph", "nointerrupt", "canelectrocute" },

		onenter = function(inst)
			inst.AnimState:PlayAnimation("run_pst")
			inst.sg.statemem.speed = CHARGE_SPEED
			inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
			inst.SoundEmitter:PlaySound("dontstarve/characters/woodie/moose/slide")
		end,

		onupdate = function(inst)
			if inst.sg.statemem.speed > .1 then
				inst.Physics:SetMotorVel(inst.sg.statemem.speed, 0, 0)
				inst.sg.statemem.speed = inst.sg.statemem.speed * .75
			elseif inst.sg.statemem.speed > 0 then
				inst.Physics:Stop()
				inst.sg.statemem.speed = 0
			end
		end,

		timeline =
		{
			TimeEvent(18 * FRAMES, function(inst)
				inst.sg:RemoveStateTag("nointerrupt")
			end),
			TimeEvent(20 * FRAMES, function(inst)
				inst.sg:GoToState("idle", true)
			end),
		},

		onexit = function(inst)
			inst.Physics:Stop()
			inst:ShowActions(true)
		end,
	},
}

-- What a client shows while it waits for the server to run the charge, as for the weremoose
local client_state = State{
	name = "beefalo_charge_pre",
	tags = { "busy" },
	server_states = { "beefalo_charge_pre", "beefalo_charge" },

	onenter = function(inst)
		inst.components.locomotor:Stop()
		inst.AnimState:PlayAnimation("run_pre")
		inst:PerformPreviewBufferedAction()
		inst.sg:SetTimeout(2)
	end,

	onupdate = function(inst)
		if inst.sg:ServerStateMatches() then
			if inst.entity:FlattenMovementPrediction() then
				inst.sg:GoToState("idle", "noanim")
			end
		elseif inst.bufferedaction == nil then
			inst.sg:GoToState("idle")
		end
	end,

	ontimeout = function(inst)
		inst:ClearBufferedAction()
		inst.sg:GoToState("idle")
	end,
}

local function initBeefaloCharge(env)
	local action = env.AddAction("BEEFALO_CHARGE", "Charge", function(act)
		local doer = act.doer
		if doer ~= nil and doer.sg ~= nil and doer.sg.currentstate.name == "beefalo_charge_pre" and IsRidingBeefalo(doer) then
			doer.sg.statemem.charging = true
			doer.sg:GoToState("beefalo_charge")
			return true
		end
	end)
	-- As ACTIONS.TACKLE, plus allowed while mounted
	action.rmb = true
	action.distance = math.huge
	action.invalid_hold_action = true
	action.mount_valid = true

	for _, state in ipairs(states) do
		env.AddStategraphState("wilson", state)
	end
	env.AddStategraphState("wilson_client", client_state)
	env.AddStategraphActionHandler("wilson", ActionHandler(action, "beefalo_charge_pre"))
	env.AddStategraphActionHandler("wilson_client", ActionHandler(action, "beefalo_charge_pre"))

	-- Offer the charge where the weremoose's is offered: the special action on open ground. On a
	-- controller that press is also how a rider dismounts, and a ground action wins over
	-- dismounting, so the charge is only offered on the move. Standing still, the press dismounts.
	env.AddComponentPostInit("playeractionpicker", function(self)
		local GetPointSpecialActions = self.GetPointSpecialActions
		self.GetPointSpecialActions = function(self, pos, useitem, right, usereticulepos)
			local controller = self.inst.components.playercontroller
			if right and useitem == nil and controller ~= nil and controller:IsEnabled() and IsRidingBeefalo(self.inst) and IsMoving(self.inst) then
				return self:SortActionList({ action }, pos)
			end
			return GetPointSpecialActions(self, pos, useitem, right, usereticulepos)
		end
	end)
end

return initBeefaloCharge
