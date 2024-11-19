name = "Bip's Extra Equip Slots"
description = "Add additional equip slots for backpack and amulets 0.1.1"
author = "Bipvanwinkle"
version = "0.1.1"
api_version = 10
dst_compatible = true
all_clients_require_mod = true

configuration_options = {
	{
		name = "BACK_SLOT",
		label = "Enable back slot",
		options = {
			{ description = "On", data = true },
			{ description = "Off", data = false },
		},
		default = true,
	},
	{
		name = "NECK_SLOT",
		label = "Enable neck slot",
		options = {
			{ description = "On", data = true },
			{ description = "Off", data = false },
		},
		default = true,
	},
}
