-- Conductor's Whistle: the Beefalo Bell's idea, for befriended clockworks, with no bonding. While a
-- survivor carries it their clockworks follow as usual. When it leaves their inventory (dropped, put
-- in a chest, handed to someone else) their clockworks stay where they are, and they rejoin when the
-- survivor carries one again. Borrows the Beefalo Bell's art for now.

local parking = require("utils.clockwork_parking")

local assets =
{
	Asset("ANIM", "anim/cowbell.zip"),
}

-- The survivor carrying this, directly or inside a backpack
local function GetHolder(inst)
	local owner = inst.components.inventoryitem:GetGrandOwner()
	return owner ~= nil and owner:HasTag("player") and owner or nil
end

local function CarriesAnotherWhistle(player, this)
	return player.components.inventory ~= nil and player.components.inventory:FindItem(function(item)
		return item.prefab == this.prefab and item ~= this
	end) ~= nil
end

local function UpdateHolder(inst)
	local holder = GetHolder(inst)
	local previous = inst._holder
	if holder == previous then
		return
	end
	inst._holder = holder
	if previous ~= nil and previous:IsValid() and not CarriesAnotherWhistle(previous, inst) then
		parking.Park(previous)
	end
	if holder ~= nil then
		parking.Unpark(holder)
	end
end

local function UpdateHolderSoon(inst)
	inst:DoTaskInTime(0, UpdateHolder)
end

local function fn()
	local inst = CreateEntity()

	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:AddSoundEmitter()
	inst.entity:AddNetwork()

	MakeInventoryPhysics(inst)

	inst.AnimState:SetBank("cowbell")
	inst.AnimState:SetBuild("cowbell")
	inst.AnimState:PlayAnimation("idle1", false)

	MakeInventoryFloatable(inst, nil, 0.05, { 1.3, 0.6, 1.3 })

	inst.entity:SetPristine()

	if not TheWorld.ismastersim then
		return inst
	end

	inst:AddComponent("inspectable")

	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem:ChangeImageName("beef_bell")

	-- The whistle can change hands without an event of its own, as when a backpack holding it is
	-- dropped, so the holder is also checked on a timer.
	inst:ListenForEvent("onputininventory", UpdateHolderSoon)
	inst:ListenForEvent("ondropped", UpdateHolderSoon)
	inst:DoPeriodicTask(1, UpdateHolder, 0)

	MakeHauntableLaunch(inst)

	return inst
end

return Prefab("conductors_whistle", fn, assets)
