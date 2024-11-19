-- modmain.lua
local debug = GLOBAL.debug
local require = GLOBAL.require
local TheInput = GLOBAL.TheInput
local ThePlayer = GLOBAL.ThePlayer
local IsServer = GLOBAL.TheNet:GetIsServer()

local BACK_SLOT = GetModConfigData("BACK_SLOT")
local NECK_SLOT = GetModConfigData("NECK_SLOT")

Assets = {
	Asset("IMAGE", "images/back.tex"),
	Asset("ATLAS", "images/back.xml"),
	Asset("IMAGE", "images/neck.tex"),
	Asset("ATLAS", "images/neck.xml"),
}

if BACK_SLOT == true or NECK_SLOT == true then
	--for key,value in pairs(GLOBAL.EQUIPSLOTS) do print('Debug EQUIPSLOTS before: ',key,value) end

	local anim_call_onequip = {}
	local anim_call_onunequip = {}

	if BACK_SLOT == true then
		GLOBAL.EQUIPSLOTS["BACK"] = "back"

		anim_call_onequip = {
			[GLOBAL.EQUIPSLOTS.BACK] = { GLOBAL.EQUIPSLOTS.BODY },
		}

		anim_call_onunequip = {
			[GLOBAL.EQUIPSLOTS.BODY] = { GLOBAL.EQUIPSLOTS.BACK },
			[GLOBAL.EQUIPSLOTS.BACK] = { GLOBAL.EQUIPSLOTS.BODY },
		}
	end

	if NECK_SLOT == true then
		GLOBAL.EQUIPSLOTS["NECK"] = "neck"

		anim_call_onequip = {
			[GLOBAL.EQUIPSLOTS.BODY] = { GLOBAL.EQUIPSLOTS.NECK },
			[GLOBAL.EQUIPSLOTS.NECK] = { GLOBAL.EQUIPSLOTS.BODY },
		}

		anim_call_onunequip = {
			[GLOBAL.EQUIPSLOTS.BODY] = { GLOBAL.EQUIPSLOTS.NECK },
			[GLOBAL.EQUIPSLOTS.NECK] = { GLOBAL.EQUIPSLOTS.BODY },
		}
	end

	if BACK_SLOT == true and NECK_SLOT == true then
		anim_call_onunequip[GLOBAL.EQUIPSLOTS.BODY] = { GLOBAL.EQUIPSLOTS.NECK, GLOBAL.EQUIPSLOTS.BACK }
	end

	--for key,value in pairs(GLOBAL.EQUIPSLOTS) do print('Debug EQUIPSLOTS after: ',key,value) end

	GLOBAL.EQUIPSLOT_IDS = {}
	local slot = 0
	for k, v in pairs(GLOBAL.EQUIPSLOTS) do
		slot = slot + 1
		GLOBAL.EQUIPSLOT_IDS[v] = slot
	end
	slot = nil

	local function FindUpvalue(fn, upvalue_name)
		local info = debug.getinfo(fn, "u")
		local nups = info and info.nups

		if not nups then
			return
		end
		for i = 1, nups do
			local name, value = debug.getupvalue(fn, i)
			if name == upvalue_name then
				return value, i
			end
		end
	end

	local function SetUpvalue(fn, new_fn, upvalue_name)
		local value, i = FindUpvalue(fn, upvalue_name)
		debug.setupvalue(fn, i, new_fn)
	end

	local body_symbol_onequip = {
		sculpture_rooknose = "swap_sculpture_rooknose",
		sculpture_knighthead = "swap_sculpture_knighthead",
		sculpture_bishophead = "swap_sculpture_bishophead",
		sunkenchest = "swap_sunken_treasurechest",
		armorsnurtleshell = "armor_slurtleshell",
		onemanband = "armor_onemanband",
		glassblock = "swap_glass_block",
		glassspike_short = "swap_glass_spike",
		glassspike_med = "swap_glass_spike",
		glassspike_tall = "swap_glass_spike",
		moon_altar_idol = "swap_altar_idolpiece",
		moon_altar_glass = "swap_altar_glasspiece",
		moon_altar_seed = "swap_altar_seedpiece",
		moon_altar_crown = "swap_altar_crownpiece",
		moon_altar_ward = "swap_altar_wardpiece",
		moon_altar_icon = "swap_altar_iconpiece",
	}

	local body_symbol_onunequip = {
		armorgrass = "armor_grass",
		armorwood = "armor_wood",
		armor_sanity = "armor_sanity",
		armormarble = "armor_marble",
		armorruins = "armor_ruins",
		armordragonfly = "torso_dragonfly",
		armor_bramble = "armor_bramble",
		armorskeleton = "armor_skeleton",
		armorslurper = "armor_slurper",
		armordreadstone = "armor_dreadstone",
		armorwagpunk = "armor_wagpunk_01",
		armor_voidcloth = "armor_voidcloth",
		armor_lunarplant = "armor_lunarplant",
		balloonvest = "balloonvest",
		raincoat = "torso_rain",
		reflectivevest = "torso_reflective",
		hawaiianshirt = "torso_hawaiian",
		beargervest = "torso_bearger",
		trunkvest_summer = "armor_trunkvest_summer",
		trunkvest_winter = "armor_trunkvest_winter",
		sweatervest = "armor_sweatervest",
		armor_snakeskin = "armor_snakeskin",
		amulet = "redamulet",
		blueamulet = "blueamulet",
		purpleamulet = "purpleamulet",
		orangeamulet = "orangeamulet",
		greenamulet = "greenamulet",
		yellowamulet = "yellowamulet",
		sculpture_rooknose = "swap_sculpture_rooknose",
		sculpture_knighthead = "swap_sculpture_knighthead",
		sculpture_bishophead = "swap_sculpture_bishophead",
		sunkenchest = "swap_sunken_treasurechest",
		armorsnurtleshell = "armor_slurtleshell",
		onemanband = "armor_onemanband",
		glassblock = "swap_glass_block",
		glassspike_short = "swap_glass_spike",
		glassspike_med = "swap_glass_spike",
		glassspike_tall = "swap_glass_spike",
		moon_altar_idol = "swap_altar_idolpiece",
		moon_altar_glass = "swap_altar_glasspiece",
		moon_altar_seed = "swap_altar_seedpiece",
		moon_altar_crown = "swap_altar_crownpiece",
		moon_altar_ward = "swap_altar_wardpiece",
		moon_altar_icon = "swap_altar_iconpiece",
	}

	local bag_symbol = {
		backpack = "swap_backpack",
		piggyback = "swap_piggyback",
		icepack = "swap_icepack",
		candybag = "candybag",
		seedpouch = "seedpouch",
		spicepack = "swap_chefpack",
		krampus_sack = "swap_krampus_sack",
	}

	AddComponentPostInit("inventory", function(self, inst)
		if BACK_SLOT == true then
			local original_Equip = self.Equip
			self.Equip = function(self, item, old_to_active, no_animation, force_ui_anim)
				if
					original_Equip(self, item, old_to_active, no_animation, force_ui_anim)
					and item
					and item.components
					and item.components.equippable
				then
					local eslot = item.components.equippable.equipslot
					if self.equipslots[eslot] ~= item then
						if eslot == GLOBAL.EQUIPSLOTS.BACK and item.components.container ~= nil then
							self.inst:PushEvent("setoverflow", { overflow = item })
						end
					end
					return true
				else
					return
				end
			end

			self.GetOverflowContainer = function()
				if self.ignoreoverflow then
					return
				end
				local item = self:GetEquippedItem(GLOBAL.EQUIPSLOTS.BACK)
				return (item ~= nil and item.components.container ~= nil and item.components.container.canbeopened)
						and item.components.container
					or nil
			end
		end

		self.inst:ListenForEvent("equip", function(inst, data)
			if inst:HasTag("player") and anim_call_onequip[data.eslot] then
				local inventory = inst.replica.inventory or inst.components.inventory
				if inventory ~= nil then
					for i, eslot in ipairs(anim_call_onequip[data.eslot]) do
						local equipment = inventory:GetEquippedItem(eslot)
						if
							equipment
							and (body_symbol_onequip[equipment.prefab] or string.match(equipment.prefab, "chesspiece_"))
							and equipment.components.equippable.onequipfn
						then
							local skin_build = equipment:GetSkinBuild()
							if skin_build ~= nil then
								if eslot == GLOBAL.EQUIPSLOTS.BODY then
									inst.AnimState:OverrideItemSkinSymbol(
										"swap_body",
										skin_build,
										"swap_body",
										equipment.GUID,
										body_symbol_onequip[equipment.prefab]
									)
								elseif NECK_SLOT == true and eslot == GLOBAL.EQUIPSLOTS.NECK then
									inst.AnimState:OverrideItemSkinSymbol(
										"swap_body",
										skin_build,
										"swap_body",
										equipment.GUID,
										"torso_amulets"
									)
								end
							else
								if eslot == GLOBAL.EQUIPSLOTS.BODY then
									if equipment.prefab == "armorsnurtleshell" or equipment.prefab == "onemanband" then
										inst.AnimState:OverrideSymbol(
											"swap_body_tall",
											body_symbol_onequip[equipment.prefab],
											"swap_body_tall"
										)
									elseif
										string.match(equipment.prefab, "chesspiece_")
										and equipment.pieceid
										and equipment.materialid
										and equipment.components.symbolswapdata
										and equipment.components.symbolswapdata.build
									then
										inst.AnimState:OverrideSymbol(
											"swap_body",
											equipment.components.symbolswapdata.build,
											"swap_body"
										)
									elseif string.match(equipment.prefab, "glassspike_") and equipment.animname then
										inst.AnimState:OverrideSymbol(
											"swap_body",
											"swap_glass_spike",
											"swap_body_" .. equipment.animname
										)
									elseif body_symbol_onequip[equipment.prefab] then
										inst.AnimState:OverrideSymbol(
											"swap_body",
											body_symbol_onequip[equipment.prefab],
											"swap_body"
										)
									end
								elseif NECK_SLOT == true and eslot == GLOBAL.EQUIPSLOTS.NECK then
									inst.AnimState:OverrideSymbol(
										"swap_body",
										"torso_amulets",
										body_symbol_onequip[equipment.prefab]
									)
								end
							end
						end
					end
				end
			end
		end)

		self.inst:ListenForEvent("unequip", function(inst, data)
			if inst:HasTag("player") and anim_call_onunequip[data.eslot] then
				local inventory = inst.replica.inventory or inst.components.inventory
				if inventory ~= nil then
					for i, eslot in ipairs(anim_call_onunequip[data.eslot]) do
						local equipment = inventory:GetEquippedItem(eslot)
						if
							equipment
							and (body_symbol_onunequip[equipment.prefab] or bag_symbol[equipment.prefab] or string.match(
								equipment.prefab,
								"chesspiece_"
							))
							and equipment.components.equippable.onequipfn
						then
							local skin_build = equipment:GetSkinBuild()
							if skin_build ~= nil then
								if eslot == GLOBAL.EQUIPSLOTS.BODY then
									inst.AnimState:OverrideItemSkinSymbol(
										"swap_body",
										skin_build,
										"swap_body",
										equipment.GUID,
										body_symbol_onunequip[equipment.prefab]
									)
								elseif BACK_SLOT == true and eslot == GLOBAL.EQUIPSLOTS.BACK then
									inst.AnimState:OverrideItemSkinSymbol(
										"backpack",
										skin_build,
										"backpack",
										equipment.GUID,
										bag_symbol[equipment.prefab]
									)
									inst.AnimState:OverrideItemSkinSymbol(
										"swap_body_tall",
										skin_build,
										"swap_body",
										equipment.GUID,
										bag_symbol[equipment.prefab]
									)
								elseif NECK_SLOT == true and eslot == GLOBAL.EQUIPSLOTS.NECK then
									inst.AnimState:OverrideItemSkinSymbol(
										"swap_body",
										skin_build,
										"swap_body",
										equipment.GUID,
										"torso_amulets"
									)
								end
							else
								if eslot == GLOBAL.EQUIPSLOTS.BODY then
									if equipment.prefab == "armorsnurtleshell" or equipment.prefab == "onemanband" then
										inst.AnimState:OverrideSymbol(
											"swap_body_tall",
											body_symbol_onunequip[equipment.prefab],
											"swap_body_tall"
										)
									elseif
										string.match(equipment.prefab, "chesspiece_")
										and equipment.pieceid
										and equipment.materialid
										and equipment.components.symbolswapdata
										and equipment.components.symbolswapdata.build
									then
										inst.AnimState:OverrideSymbol(
											"swap_body",
											equipment.components.symbolswapdata.build,
											"swap_body"
										)
									elseif string.match(equipment.prefab, "glassspike_") and equipment.animname then
										inst.AnimState:OverrideSymbol(
											"swap_body",
											"swap_glass_spike",
											"swap_body_" .. equipment.animname
										)
									elseif body_symbol_onunequip[equipment.prefab] then
										inst.AnimState:OverrideSymbol(
											"swap_body",
											body_symbol_onunequip[equipment.prefab],
											"swap_body"
										)
									end
								elseif BACK_SLOT == true and eslot == GLOBAL.EQUIPSLOTS.BACK then
									inst.AnimState:OverrideSymbol("backpack", bag_symbol[equipment.prefab], "backpack")
									inst.AnimState:OverrideSymbol(
										"swap_body_tall",
										bag_symbol[equipment.prefab],
										"swap_body"
									)
								elseif NECK_SLOT == true and eslot == GLOBAL.EQUIPSLOTS.NECK then
									inst.AnimState:OverrideSymbol(
										"swap_body",
										"torso_amulets",
										body_symbol_onunequip[equipment.prefab]
									)
								end
							end
						end
					end
				end
			end
		end)
	end)

	Inv = require("widgets/inventorybar")
	AddClassPostConstruct("widgets/inventorybar", function(self)
		local Inv_Refresh_base = Inv.Refresh or function()
			return ""
		end
		local Inv_Rebuild_base = Inv.Rebuild or function()
			return ""
		end

		function Inv:LoadExtraSlots(self)
			if self.addextraslots == nil then
				self.addextraslots = 1

				if BACK_SLOT == true then
					self:AddEquipSlot(GLOBAL.EQUIPSLOTS.BACK, "images/back.xml", "back.tex")
				end
				if NECK_SLOT == true then
					self:AddEquipSlot(GLOBAL.EQUIPSLOTS.NECK, "images/neck.xml", "neck.tex")
				end
			end

			if self.inspectcontrol then
				local W = 68
				local SEP = 12
				local INTERSEP = 28
				local inventory = self.owner.replica.inventory
				local num_slots = inventory:GetNumSlots()
				local num_equip = #self.equipslotinfo
				local num_buttons = self.controller_build and 0 or 1
				local num_slotintersep = math.ceil(num_slots / 5)
				local num_equipintersep = num_buttons > 0 and 1 or 0
				local total_w_default = (num_slots + 3 + num_buttons) * W
					+ (num_slots + 3 + num_buttons - num_slotintersep - num_equipintersep - 1) * SEP
					+ (num_slotintersep + num_equipintersep) * INTERSEP
				local total_w = (num_slots + num_equip + num_buttons) * W
					+ (num_slots + num_equip + num_buttons - num_slotintersep - num_equipintersep - 1) * SEP
					+ (num_slotintersep + num_equipintersep) * INTERSEP
				local scale = 1.22 * total_w / total_w_default

				self.bg:SetScale(scale, 1, 1)
				self.bgcover:SetScale(scale, 1, 1)

				self.inspectcontrol.icon:SetScale(0.7)
				self.inspectcontrol.icon:SetPosition(-4, 6)
				self.inspectcontrol:SetScale(1.25)
				self.inspectcontrol:SetPosition((total_w - W) * 0.5 + 3, -7, 0)
			end
		end

		function Inv:Refresh()
			Inv_Refresh_base(self)
			Inv:LoadExtraSlots(self)
		end

		function Inv:Rebuild()
			Inv_Rebuild_base(self)
			Inv:LoadExtraSlots(self)
		end
	end)

	if BACK_SLOT == true then
		AddPrefabPostInit("inventory_classified", function(inst)
			function GetOverflowContainer(inst)
				if inst.ignoreoverflow then
					return
				end
				local item = inst.GetEquippedItem(inst, GLOBAL.EQUIPSLOTS.BACK)
				return item ~= nil and item.replica.container or nil
			end

			if not IsServer then
				inst.GetOverflowContainer = GetOverflowContainer
				if inst["Has"] and type(inst["Has"]) == "function" then
					SetUpvalue(inst["Has"], GetOverflowContainer, "GetOverflowContainer")
				end
			end
		end)
	end

	if NECK_SLOT == true then
		AddStategraphPostInit("wilson", function(self)
			for key, value in pairs(self.states) do
				if value.name == "amulet_rebirth" then
					local original_amulet_rebirth_onenter = self.states[key].onenter
					local original_amulet_rebirth_onexit = self.states[key].onexit

					self.states[key].onenter = function(inst)
						original_amulet_rebirth_onenter(inst)
						local item = inst.components.inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.NECK)
						if item ~= nil and item.prefab == "amulet" then
							item = inst.components.inventory:RemoveItem(item)
							if item ~= nil then
								item:Remove()
								inst.sg.statemem.usedamulet_exslots = true
							end
						end
					end

					self.states[key].onexit = function(inst)
						if
							inst.sg.statemem.usedamulet_exslots
							and inst.components.inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.NECK) == nil
						then
							inst.AnimState:ClearOverrideSymbol("swap_body")
						end
						original_amulet_rebirth_onexit(inst)
					end
				end
			end
		end)
	end

	local function backpack_onequip(inst, owner)
		if owner:HasTag("player") then
			local skin_build = inst:GetSkinBuild()
			if skin_build ~= nil then
				owner:PushEvent("equipskinneditem", inst:GetSkinName())
				owner.AnimState:OverrideItemSkinSymbol(
					"backpack",
					skin_build,
					"backpack",
					inst.GUID,
					bag_symbol[inst.prefab]
				)
				owner.AnimState:OverrideItemSkinSymbol(
					"swap_body_tall",
					skin_build,
					"swap_body",
					inst.GUID,
					bag_symbol[inst.prefab]
				)
			else
				owner.AnimState:OverrideSymbol("backpack", bag_symbol[inst.prefab], "backpack")
				owner.AnimState:OverrideSymbol("swap_body_tall", bag_symbol[inst.prefab], "swap_body")
			end

			if inst.components.container ~= nil then
				inst.components.container:Open(owner)
			end
		else
			inst.components.equippable.orig_onequipfn(inst, owner)
		end
	end

	local function backpack_onunequip(inst, owner)
		if owner:HasTag("player") then
			local skin_build = inst:GetSkinBuild()
			if skin_build ~= nil then
				owner:PushEvent("unequipskinneditem", inst:GetSkinName())
			end
			owner.AnimState:ClearOverrideSymbol("swap_body_tall")
			owner.AnimState:ClearOverrideSymbol("backpack")

			if inst.components.container ~= nil then
				inst.components.container:Close(owner)
			end
		else
			inst.components.equippable.orig_onunequipfn(inst, owner)
		end
	end

	function amulet_postinit(inst)
		inst.components.equippable.equipslot = GLOBAL.EQUIPSLOTS.NECK or GLOBAL.EQUIPSLOTS.BODY
	end

	function backpack_postinit(inst)
		if BACK_SLOT == true then
			inst.components.equippable.equipslot = GLOBAL.EQUIPSLOTS.BACK or GLOBAL.EQUIPSLOTS.BODY
		end
		inst.components.equippable.orig_onequipfn = inst.components.equippable.onequipfn
		inst.components.equippable.orig_onunequipfn = inst.components.equippable.onunequipfn
		inst.components.equippable:SetOnEquip(backpack_onequip)
		inst.components.equippable:SetOnUnequip(backpack_onunequip)
	end

	if IsServer then
		if NECK_SLOT == true then
			local amulets = { "amulet", "blueamulet", "greenamulet", "orangeamulet", "purpleamulet", "yellowamulet" }
			for _, amulet in ipairs(amulets) do
				AddPrefabPostInit(amulet, amulet_postinit)
			end
		end

		local backpacks = { "backpack", "piggyback", "icepack", "candybag", "seedpouch", "spicepack", "krampus_sack" }
		for _, backpack in ipairs(backpacks) do
			AddPrefabPostInit(backpack, backpack_postinit)
		end
	end
end
