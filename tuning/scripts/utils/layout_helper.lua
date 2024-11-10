local function generateSlotPositions(rows, cols, x_offset, y_offset, x_gap, y_gap, Vector3)
	local slotpos = {}
	for y = 0, rows - 1 do
		for x = 0, cols - 1 do
			table.insert(slotpos, Vector3(x * x_gap + x_offset, y * y_gap + y_offset, 0))
		end
	end
	return slotpos
end

return {
	generateSlotPositions = generateSlotPositions,
}
