local function generateSlotPositions(rows, cols, x_offset, y_offset, x_gap, y_gap, Vector3)
	local slot_positions = {}
	for y = 0, rows - 1 do
		for x = 0, cols - 1 do
			local slot_postion = Vector3(x * x_gap + x_offset, y * y_gap + y_offset, 0)
			table.insert(slot_positions, slot_postion)
		end
	end
	return slot_positions
end

-- Grid centered on the widget origin, which is where chest-type UI backgrounds are anchored
local function generateCenteredSlotPositions(rows, cols, gap, Vector3)
	local x_offset = -gap * (cols - 1) / 2
	local y_offset = gap * (rows - 1) / 2
	return generateSlotPositions(rows, cols, x_offset, y_offset, gap, -gap, Vector3)
end

return {
	generateSlotPositions = generateSlotPositions,
	generateCenteredSlotPositions = generateCenteredSlotPositions,
}
