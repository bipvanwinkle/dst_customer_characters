name = "Bip's Custom DST Tuning"
description = "Customizes the game for my personal enjoyment 1.28.0"
author = "Bipvanwinkle"
version = "1.28.0"
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
		name = "wx78_super_illumination_radius",
		label = "WX78 Super-Illumination Radius",
		hover = "Light from each Super-Illumination Circuit, relative to an Illumination Circuit",
		options = {
			{ description = "Same (1x)", data = 1 },
			{ description = "1.5x", data = 1.5 },
			{ description = "2x", data = 2 },
			{ description = "3x", data = 3 },
		},
		default = 2,
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
	{
		name = "naughtiness_multiplier",
		label = "Naughtiness Multiplier",
		hover = "Multiplies the naughtiness from killing innocent creatures, which summons Krampus",
		options = {
			{ description = "Default (1x)", data = 1 },
			{ description = "1.5x", data = 1.5 },
			{ description = "2x", data = 2 },
			{ description = "3x", data = 3 },
		},
		default = 1.5,
	},
	{
		name = "explosive_resist_cap",
		label = "Explosive Resistance Cap",
		hover = "Explosive damage a boss takes in one burst before it becomes immune to explosions",
		options = {
			{ description = "Default (8,000)", data = 8000 },
			{ description = "16,000", data = 16000 },
			{ description = "32,000", data = 32000 },
		},
		default = 16000,
	},
	{
		name = "walking_stick_key",
		label = "Walking Stick Key",
		hover = "Equips a Walking Cane or Wooden Walking Stick from your inventory or backpack; press again to swap back. To use a controller back button, bind it to this key in the Steam controller layout",
		options = {
			{ description = "Off", data = false },
			{ description = "F5", data = "F5" },
			{ description = "F6", data = "F6" },
			{ description = "F7", data = "F7" },
			{ description = "F8", data = "F8" },
			{ description = "F9", data = "F9" },
		},
		default = "F6",
	},
	{
		name = "skill_points",
		label = "Skill Points",
		hover = "Most insight points a survivor can earn. Each point past 15 costs 5 days survived, and banked days count",
		options = {
			{ description = "Default (15)", data = 15 },
			{ description = "18", data = 18 },
			{ description = "20", data = 20 },
			{ description = "25", data = 25 },
			{ description = "33", data = 33 },
		},
		default = 20,
	},
	{
		name = "clockwork_gear_damage",
		label = "Clockwork Gear Damage",
		hover = "Damage bonus per gear. WX-78 gives Gears to his clockworks, up to 5 each. Bishops, Knights and Rooks weight this differently, and Chessmaster Circuits add 20% each",
		options = {
			{ description = "+4%", data = 0.04 },
			{ description = "+7%", data = 0.07 },
			{ description = "+10%", data = 0.1 },
			{ description = "+15%", data = 0.15 },
			{ description = "+20%", data = 0.2 },
		},
		default = 0.1,
	},
	{
		name = "clockwork_gear_reduction",
		label = "Clockwork Gear Damage Reduction",
		hover = "Damage reduction per gear, to a ceiling of 75%. WX-78 gives Gears to his clockworks, up to 5 each. Bishops, Knights and Rooks weight this differently, and Chessmaster Circuits add 20% each",
		options = {
			{ description = "2%", data = 0.02 },
			{ description = "4%", data = 0.04 },
			{ description = "6%", data = 0.06 },
			{ description = "8%", data = 0.08 },
			{ description = "10%", data = 0.1 },
		},
		default = 0.06,
	},
	{
		name = "clockwork_gear_health",
		label = "Clockwork Gear Health",
		hover = "Maximum health per gear. WX-78 gives Gears to his clockworks, up to 5 each. Bishops, Knights and Rooks weight this differently, and Chessmaster Circuits add 20% each",
		options = {
			{ description = "+50", data = 50 },
			{ description = "+100", data = 100 },
			{ description = "+150", data = 150 },
			{ description = "+225", data = 225 },
			{ description = "+300", data = 300 },
		},
		default = 150,
	},
	{
		name = "clockwork_gear_regen",
		label = "Clockwork Gear Regeneration",
		hover = "Extra health regenerated every 3 seconds out of combat, per gear. WX-78 gives Gears to his clockworks, up to 5 each. Bishops, Knights and Rooks weight this differently, and Chessmaster Circuits add 20% each",
		options = {
			{ description = "+1", data = 1 },
			{ description = "+2", data = 2 },
			{ description = "+4", data = 4 },
			{ description = "+6", data = 6 },
			{ description = "+8", data = 8 },
		},
		default = 4,
	},
	{
		name = "beefalo_charge",
		label = "Beefalo Charge",
		hover = "While riding a beefalo, the weremoose's charge: the special action on open ground sends it charging through creatures, and into trees and boulders",
		options = {
			{ description = "Off", data = false },
			{ description = "On", data = true },
		},
		default = true,
	},
}
