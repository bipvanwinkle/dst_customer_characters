local actualModname = KnownModIndex:GetModActualName("Bip's Custom DST Tuning")
local thermal_stone_duration = GetModConfigData("thermal_stone_duration", actualModname)

local function adjustThermalStone(inst)
	if inst.components.fueled then
		inst.components.fueled:InitializeFuelLevel(inst.components.fueled.maxfuel * thermal_stone_duration)
	end
end

local function initThermalStone(addPrefabPostInit)
	addPrefabPostInit("heatrock", adjustThermalStone)
end

return initThermalStone
