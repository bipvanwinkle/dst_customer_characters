-- A bishop that follows a survivor keeps its distance in a fight.
--
-- The bishop's brain only chases and attacks. It stops at its own range, but it never moves away,
-- so whatever walks up to it hits it freely between shots. Here an allied bishop backs away from
-- a target that has come close while its shot is on cooldown, then turns and fires again. Wild
-- bishops fight as they always have.

require("behaviours/runaway")

local START_DIST = 5 -- a target nearer than this is too close
local STOP_DIST = 7 -- back away to this, a little inside the bishop's range of 8

local function IsAllied(inst)
	local leader = inst.components.follower ~= nil and inst.components.follower:GetLeader() or nil
	return leader ~= nil and leader.isplayer
end

-- A shot comes first: the bishop only gives ground while it has nothing to fire
local function ShouldKeepDistance(inst)
	return IsAllied(inst) and inst.components.combat:HasTarget() and inst.components.combat:InCooldown()
end

local function GetTarget(inst)
	return inst.components.combat.target
end

local function OnBrainStarted(brain)
	local inst = brain.inst
	local root = brain.bt.root
	for i, node in ipairs(root.children) do
		if node.name == "ChaseAndAttack" then
			local keepdistance = WhileNode(function() return ShouldKeepDistance(inst) end, "KeepDistance",
				RunAway(inst, { getfn = GetTarget }, START_DIST, STOP_DIST, nil, nil, nil, true)) -- true to walk, as the chase does
			keepdistance.parent = root
			table.insert(root.children, i, keepdistance)
			return
		end
	end
end

local function init(env)
	env.AddBrainPostInit("bishopbrain", OnBrainStarted)
end

return init
