name = "Bip's Custom DST Tuning"
description = "Customizes the game for my personal enjoyment 1.24.0"
author = "Bipvanwinkle"
version = "1.24.0"
api_version = 10
dst_compatible = true
all_clients_require_mod = true
-- The workshop mod.manifest only lists files from the last upload, so files added by
-- `make deploy-tuning` between uploads would be invisible to require() with it enabled
forcemanifest = false

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
		name = "chest_slots",
		label = "Chest Slot Count",
		options = {
			{ description = "Default (9)", data = 9 },
			{ description = "Huge (25)", data = 25 },
		},
		default = 25,
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
	{
		name = "wx78_gear_indicator",
		label = "WX78 Gear Indicator",
		hover = "Shows how many gears WX-78 has eaten below the status meters",
		options = {
			{ description = "On", data = true },
			{ description = "Off", data = false },
		},
		default = true,
	},
	{
		name = "beefalo_riding_insulation",
		label = "Beefalo Riding Warmth",
		hover = "Winter insulation while riding a beefalo; a shaved beefalo gives half",
		options = {
			{ description = "Off", data = 0 },
			{ description = "Tiny (30)", data = 30 },
			{ description = "Small (60)", data = 60 },
			{ description = "Medium (120)", data = 120 },
			{ description = "Large (240)", data = 240 },
		},
		default = 60,
	},
	{
		name = "treeguard_chance_multiplier",
		label = "Treeguard Chance Multiplier",
		hover = "Multiplies the treeguard chance per tree chopped, on top of the world's Treeguards setting",
		options = {
			{ description = "Default (1x)", data = 1 },
			{ description = "2x", data = 2 },
			{ description = "3x", data = 3 },
			{ description = "4x", data = 4 },
		},
		default = 2,
	},
	{
		name = "blowdart_craft_count",
		label = "Blow Darts per Craft",
		hover = "How many blow darts each blow dart recipe makes",
		options = {
			{ description = "Default (1)", data = 1 },
			{ description = "2", data = 2 },
			{ description = "3", data = 3 },
			{ description = "5", data = 5 },
		},
		default = 3,
	},
	{
		name = "saltlick_durability_multiplier",
		label = "Salt Lick Durability",
		hover = "Multiplies how many licks a salt lick (regular and improved) lasts",
		options = {
			{ description = "Default (1x)", data = 1 },
			{ description = "2x", data = 2 },
			{ description = "5x", data = 5 },
			{ description = "10x", data = 10 },
		},
		default = 10,
	},
}
