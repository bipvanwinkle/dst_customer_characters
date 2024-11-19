name = "Bip's Custom DST Tuning"
description = "Customizes the game for my personal enjoyment 1.17.5"
author = "Bipvanwinkle"
version = "1.17.5"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

configuration_options = {
	{
		name = "fridge_spoil_rate",
		label = "Fridge Spoilage Rate",
		options = {
			{ description = "Default", data = 0.5 },
			{ description = "Slower", data = 0.25 },
			{ description = "Much Slower", data = 0.125 },
		},
		default = 0.5,
	},
	{
		name = "fridge_slots",
		label = "Fridge Slot Count",
		options = {
			{ description = "Default (9)", data = 9 },
			{ description = "Large (12)", data = 12 },
			{ description = "Extra Large (15)", data = 15 },
		},
		default = 9,
	},
	{
		name = "reverse_frozen_items",
		label = "Fridge Reverses Frozen Spoilage",
		options = {
			{ description = "False", data = false },
			{ description = "True", data = true },
		},
		default = true,
	},
	{
		name = "chester_slots",
		label = "Chester Slot Count",
		options = {
			{ description = "Default (9)", data = 9 },
			{ description = "Large (12)", data = 12 },
			{ description = "Extra Large (15)", data = 15 },
		},
		default = 9,
	},
	{
		name = "chester_health_multiplier",
		label = "Chester Health Multiplier",
		options = {
			{ description = "Default (1)", data = 1 },
			{ description = "Double (2)", data = 2 },
			{ description = "Triple (3)", data = 3 },
		},
		default = 1,
	},
	{
		name = "backpack_slots",
		label = "Backpack Slot Count",
		options = {
			{ description = "8(default)", data = 8 },
			{ description = "10", data = 10 },
			{ description = "12", data = 12 },
			{ description = "14", data = 14 },
			{ description = "16", data = 16 },
			{ description = "18", data = 18 },
		},
		default = 9,
	},
	{
		name = "thermal_stone_duration",
		label = "Thermal Stone Duration",
		options = {
			{ description = "Default", data = 1 },
			{ description = "Longer", data = 1.5 },
			{ description = "Much Longer", data = 2 },
			{ description = "Very Very Long", data = 10 },
		},
		default = 1,
	},
	{
		name = "wx78_circuit_slots",
		label = "WX78 Circuit Slots",
		options = {
			{ description = "Default", data = 6 },
			{ description = "8", data = 8 },
			{ description = "10", data = 10 },
			{ description = "12", data = 12 },
		},
		default = 6,
	},
}
