-- Make sure this mod only affects Wigfrid (prefab: "wigfrid")
local function AddLifesteal(inst)
	-- Function to give health when Wigfrid hits an enemy
	local function onhit(inst, data)
		-- Check if the target exists and damage has been done
		if data and data.target and data.damage then
			local heal_amount = data.damage * 0.1 -- 10% of damage dealt as healing
			inst.components.health:DoDelta(heal_amount)
		end
	end

	-- Listen for the "onhitother" event, which occurs when Wigfrid hits something
	inst:ListenForEvent("onhitother", onhit)
end

-- Add our lifesteal ability only to Wigfrid
local function WigfridPostInit(inst)
	if inst.prefab == "wigfrid" then
		AddLifesteal(inst)
	end
end

-- Hook into the character prefab post initialization
AddPrefabPostInit("wigfrid", WigfridPostInit)
