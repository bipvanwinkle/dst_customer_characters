local actualModname = KnownModIndex:GetModActualName("Bip's Custom DST Tuning")
local fridge_spoil_rate = GetModConfigData("fridge_spoil_rate", actualModname)

local function adjustFridge(inst)
	if inst.components.preserver then
		inst.components.preserver:SetPerishRateMultiplier(fridge_spoil_rate)
	end
end

local function initIcebox(addPrefabPostInit)
	addPrefabPostInit("icebox", adjustFridge)
end

return initIcebox
