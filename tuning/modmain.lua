-- Import the modules
local initThermalStone = require("components.thermal_stone")
local initIcebox = require("components.icebox")
local layout_helper = require("utils.layout_helper")
local containers = GLOBAL.require("containers")
local Vector3 = GLOBAL.Vector3

local chester_slots = GetModConfigData("chester_slots")
local icebox_slots = GetModConfigData("fridge_slots")
local backpack_slots = GetModConfigData("backpack_slots")

-- Ensure networked slot syncing
local function addItemSlotNetvarsInContainer(inst)
	if #inst._itemspool < containers.MAXITEMSLOTS then
		for i = #inst._itemspool + 1, containers.MAXITEMSLOTS do
			table.insert(
				inst._itemspool,
				GLOBAL.net_entity(
					inst.GUID,
					"container._items[" .. tostring(i) .. "]",
					"items[" .. tostring(i) .. "]dirty"
				)
			)
		end
	end
end
AddPrefabPostInit("container_classified", addItemSlotNetvarsInContainer)

-- Adjust container layouts based on configurations
local original_widgetsetup = containers.widgetsetup or function()
	return true
end
function containers.widgetsetup(container, prefab, data)
	local tempPrefab = prefab or container.inst.prefab
	local result = original_widgetsetup(container, prefab, data)
	local updated = false

	if tempPrefab == "chester" and chester_slots then
		container.widget.slotpos =
			layout_helper.generateSlotPositions(chester_slots / 3, 3, -162, 114, 75, -75, Vector3)
		container.widget.animbank = "ui_chester_shadow_3x4"
		container.widget.animbuild = "ui_chester_shadow_3x4"
		updated = true
	elseif tempPrefab == "icebox" and icebox_slots then
		container.widget.slotpos = layout_helper.generateSlotPositions(icebox_slots / 3, 3, -162, 114, 75, -75, Vector3)
		container.widget.animbank = "ui_chester_shadow_3x4"
		container.widget.animbuild = "ui_chester_shadow_3x4"
		updated = true
	elseif tempPrefab == "backpack" and backpack_slots then
		container.widget.slotpos =
			layout_helper.generateSlotPositions(backpack_slots / 2, 2, -162, 115, 75, -75, Vector3)
		container.widget.animbank = "ui_krampusbag_2x5"
		container.widget.animbuild = "ui_krampusbag_2x5"
		updated = true
	end

	if updated then
		container:SetNumSlots(#container.widget.slotpos)
	end

	return result
end

-- Initialize the modules
initThermalStone(AddPrefabPostInit)
initIcebox(AddPrefabPostInit)
