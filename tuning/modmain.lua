-- Import the modules
local initThermalStone = require("components.thermal_stone")
local layout_helper = require("utils.layout_helper")
local containers = GLOBAL.require("containers")
local Vector3 = GLOBAL.Vector3

-- Container UI backgrounds reused for the resized containers
Assets = {
	Asset("ANIM", "anim/ui_chester_shadow_3x4.zip"),
	Asset("ANIM", "anim/ui_fish_box_5x4.zip"),
	Asset("ANIM", "anim/ui_krampusbag_2x5.zip"),
}

local chester_slots = GetModConfigData("chester_slots")
local chester_health_multiplier = GetModConfigData("chester_health_multiplier")
local icebox_slots = GetModConfigData("fridge_slots")
local backpack_slots = GetModConfigData("backpack_slots")
local chest_slots = GetModConfigData("chest_slots")
local circuit_slots = GetModConfigData("wx78_circuit_slots")
local reverse_frozen_items = GetModConfigData("reverse_frozen_items")
local fridge_spoil_rate = GetModConfigData("fridge_spoil_rate")
local beefalo_riding_insulation = GetModConfigData("beefalo_riding_insulation") or 0
local treeguard_chance_multiplier = GetModConfigData("treeguard_chance_multiplier") or 1
local blowdart_craft_count = GetModConfigData("blowdart_craft_count") or 1
local saltlick_durability_multiplier = GetModConfigData("saltlick_durability_multiplier") or 1
local naughtiness_multiplier = GetModConfigData("naughtiness_multiplier") or 1

--Changes to Perishables to make it so that frozen items
--reverse their perish rate when they are in a fridge
local function UpdatePerishable(inst, dt)
	local FRAMES = GLOBAL.FRAMES or (1 / 30)
	local TUNING = GLOBAL.TUNING
	local TheWorld = GLOBAL.TheWorld
	local self = inst.components.perishable
	if self ~= nil then
		dt = self.start_dt or dt or (10 + math.random() * FRAMES * 8)
		self.start_dt = nil

		local additional_decay = 0
		local modifier = 1
		local owner = inst.components.inventoryitem and inst.components.inventoryitem.owner or nil
		if not owner and inst.components.occupier then
			owner = inst.components.occupier:GetOwner()
		end

		local pos = owner ~= nil and owner:GetPosition() or self.inst:GetPosition()
		local inside_pocket_container = owner ~= nil and owner:HasTag("pocketdimension_container")

		local ambient_temperature = inside_pocket_container and TheWorld.state.temperature
			or GLOBAL.GetTemperatureAtXZ(pos.x, pos.z)

		if owner then
			if owner.components.preserver ~= nil then
				modifier = owner.components.preserver:GetPerishRateMultiplier(inst) or modifier
			elseif owner:HasTag("fridge") then
				if inst:HasTag("frozen") and not owner:HasTag("nocool") and not owner:HasTag("lowcool") then
					modifier = -TUNING.PERISH_FRIDGE_MULT
				else
					modifier = TUNING.PERISH_FRIDGE_MULT
				end
			elseif owner:HasTag("foodpreserver") then
				modifier = TUNING.PERISH_FOOD_PRESERVER_MULT
			elseif owner:HasTag("cage") and inst:HasTag("small_livestock") then
				modifier = TUNING.PERISH_CAGE_MULT
			end

			if owner:HasTag("spoiler") then
				modifier = modifier * TUNING.PERISH_GROUND_MULT
			end
		else
			modifier = TUNING.PERISH_GROUND_MULT
			if TheWorld.state.isacidraining and inst.components.rainimmunity == nil then
				local rate = (
					inst.components.moisture and inst.components.moisture:_GetMoistureRateAssumingRain()
					or TheWorld.state.precipitationrate
				)
				local percent_to_reduce = rate * TUNING.ACIDRAIN_PERISHABLE_ROT_PERCENT * dt

				local perish_time = (self.perishtime and self.perishtime > 0 and self.perishtime or 0)
				additional_decay = perish_time * percent_to_reduce
			end
		end

		if inst:GetIsWet() and not self.ignorewentness then
			modifier = modifier * TUNING.PERISH_WET_MULT
		end

		if ambient_temperature < 0 then
			if inst:HasTag("frozen") and not self.frozenfiremult then
				modifier = TUNING.PERISH_COLD_FROZEN_MULT
			else
				modifier = modifier * TUNING.PERISH_WINTER_MULT
			end
		end

		if self.frozenfiremult then
			modifier = modifier * TUNING.PERISH_FROZEN_FIRE_MULT
		end

		if ambient_temperature > TUNING.OVERHEAT_TEMP then
			modifier = modifier * TUNING.PERISH_SUMMER_MULT
		end

		modifier = modifier * self.localPerishMultiplyer

		modifier = modifier * TUNING.PERISH_GLOBAL_MULT

		local old_val = self.perishremainingtime
		if self.perishremainingtime then
			self.perishremainingtime =
				math.max(math.min(self.perishtime, self.perishremainingtime - dt * modifier - additional_decay), 0)
			if math.floor(old_val * 100) ~= math.floor(self.perishremainingtime * 100) then
				inst:PushEvent("perishchange", { percent = self:GetPercent() })
			end
		end

		--Cool off hot foods over time (faster if in a fridge)
		--Skip and retain heat in containers with "nocool" tag
		if
			inst.components.edible ~= nil
			and inst.components.edible.temperaturedelta ~= nil
			and inst.components.edible.temperaturedelta > 0
			and not (owner ~= nil and owner:HasTag("nocool"))
		then
			if owner ~= nil and owner:HasTag("fridge") then
				inst.components.edible:AddChill(1)
			elseif ambient_temperature < TUNING.OVERHEAT_TEMP - 5 then
				inst.components.edible:AddChill(0.25)
			end
		end

		--trigger the next callback
		if self.perishremainingtime and self.perishremainingtime <= 0 then
			self:Perish()
		end
	end
end

local function PerishablePostInit(self)
	local FRAMES = GLOBAL.FRAMES or (1 / 30)
	-- Override StartPerishing
	function self:StartPerishing()
		if self.updatetask ~= nil then
			self.updatetask:Cancel()
			self.updatetask = nil
		end

		local dt = 10 + math.random() * FRAMES * 8
		self.start_dt = math.random() * 2
		self.updatetask = self.inst:DoPeriodicTask(dt, UpdatePerishable, self.start_dt, dt)
	end

	-- Override LongUpdate
	function self:LongUpdate(dt)
		if self.updatetask ~= nil then
			UpdatePerishable(self.inst, dt or 0)
		end
	end
end

-- Inject custom behavior into the Perishable component
if reverse_frozen_items then
	print("Adding PostInit Callback for perishable")
	AddComponentPostInit("perishable", PerishablePostInit)
end

--Modification of GLOBAL.TUNING

GLOBAL.TUNING.WX78_MAXELECTRICCHARGE = circuit_slots
GLOBAL.TUNING.CHESTER_HEALTH = GLOBAL.TUNING.CHESTER_HEALTH * chester_health_multiplier
GLOBAL.TUNING.PERISH_FRIDGE_MULT = fridge_spoil_rate
-- Read when a salt lick spawns; the improved lick's salt rock repair value scales with it too
GLOBAL.TUNING.SALTLICK_MAX_LICKS = GLOBAL.TUNING.SALTLICK_MAX_LICKS * saltlick_durability_multiplier
GLOBAL.TUNING.SALTLICK_IMPROVED_MAX_LICKS = GLOBAL.TUNING.SALTLICK_IMPROVED_MAX_LICKS * saltlick_durability_multiplier

-- Make sure enough networked slots exist for the largest configured container
containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, chester_slots, icebox_slots, backpack_slots, chest_slots)

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
-- The widget table is shared between prefabs (e.g. chester/hutch, treasurechest/pandoraschest),
-- so copy it before applying overrides rather than mutating it in place
local function overrideWidget(container, overrides)
	local widget = {}
	for k, v in pairs(container.widget) do
		widget[k] = v
	end
	for k, v in pairs(overrides) do
		widget[k] = v
	end
	container.widget = widget
end

-- Lay out a centered grid of slots over a background anim, stretching the
-- background vertically when there are more (or fewer) rows than it was drawn for
local function centeredGridWidget(rows, cols, anim, anim_rows)
	return {
		slotpos = layout_helper.generateCenteredSlotPositions(rows, cols, 75, Vector3),
		animbank = anim,
		animbuild = anim,
		animbank_upgraded = anim,
		animbuild_upgraded = anim,
		bgscale = Vector3(1, rows / anim_rows, 1),
	}
end

function containers.widgetsetup(container, prefab, data)
	local tempPrefab = prefab or container.inst.prefab
	local result = original_widgetsetup(container, prefab, data)
	local overrides = nil

	if tempPrefab == "chester" and chester_slots then
		overrides = centeredGridWidget(chester_slots / 3, 3, "ui_chester_shadow_3x4", 4)
	elseif tempPrefab == "icebox" and icebox_slots then
		overrides = centeredGridWidget(icebox_slots / 3, 3, "ui_chester_shadow_3x4", 4)
	elseif tempPrefab == "treasurechest" and chest_slots and chest_slots > 9 then
		overrides = centeredGridWidget(chest_slots / 5, 5, "ui_fish_box_5x4", 4)
		overrides.pos = Vector3(0, 220, 0)
	elseif tempPrefab == "backpack" and backpack_slots then
		overrides = {
			slotpos = layout_helper.generateSlotPositions(backpack_slots / 2, 2, -162, 115, 75, -75, Vector3),
			animbank = "ui_krampusbag_2x5",
			animbuild = "ui_krampusbag_2x5",
		}
	end

	if overrides ~= nil then
		overrideWidget(container, overrides)
		container:SetNumSlots(#container.widget.slotpos)
	end

	return result
end

-- Apply the optional background stretch from centeredGridWidget when a container UI opens
AddClassPostConstruct("widgets/containerwidget", function(self)
	local old_open = self.Open
	function self:Open(container, doer)
		old_open(self, container, doer)
		local widget = container.replica.container:GetWidget()
		local bgscale = widget ~= nil and widget.bgscale or nil
		if bgscale ~= nil then
			self.bganim:SetScale(bgscale.x, bgscale.y, bgscale.z)
		else
			self.bganim:SetScale(1, 1, 1)
		end
	end
end)

-- Both gear upgrades reach their maximum at WX78_MAX_GEARS gears eaten
local WX78_MAX_GEARS = 18
local WX78_MAX_ABSORPTION_DUE_TO_GEARS = 0.5
local WX78_MAX_DAMAGE_AMP = 2.0

-- Use gears to upgrade WX-78
local function WX78PostInit(inst)
	-- Synced to clients for the gear indicator; declared on server and client alike
	inst._gears_eaten_net = GLOBAL.net_smallbyte(inst.GUID, "wx78._gears_eaten_net", "wx78_gearsdirty")

	if not GLOBAL.TheWorld.ismastersim then
		return
	end

	local old_on_eat = (inst.components.eater and inst.components.eater.oneatfn) or function()
		return true
	end

	local function apply_gear_upgrades(inst)
		local gears = math.min(inst._gears_eaten, WX78_MAX_GEARS)

		if inst.components.health ~= nil then
			local new_absorb = gears / WX78_MAX_GEARS * WX78_MAX_ABSORPTION_DUE_TO_GEARS
			inst.components.health.externalabsorbmodifiers:SetModifier(inst, new_absorb, "wx_gear_eaten")
		end

		if inst.components.combat ~= nil then
			local new_damage_amp = 1 + gears / WX78_MAX_GEARS * (WX78_MAX_DAMAGE_AMP - 1)
			inst.components.combat.externaldamagemultipliers:SetModifier(inst, new_damage_amp, "wx_gear_eaten")
		end

		inst._gears_eaten_net:set(gears)
	end

	local function OnEat(inst, food)
		old_on_eat(inst, food)

		if food ~= nil and food.components.edible ~= nil then
			if food.components.edible.foodtype == GLOBAL.FOODTYPE.GEARS then
				apply_gear_upgrades(inst)
			end
		end
	end

	if inst.components.eater ~= nil then
		inst.components.eater:SetOnEatFn(OnEat)
	end

	-- The base game drops gears and zeroes _gears_eaten on death, so reset the upgrades to match.
	-- Registered after the base game's listeners, so they run after the count is cleared.
	inst:ListenForEvent("death", apply_gear_upgrades)
	inst:ListenForEvent("ms_respawnedfromghost", apply_gear_upgrades)

	local old_on_load = inst.OnLoad or function()
		return true
	end
	local function OnLoad(inst, data)
		old_on_load(inst, data)

		apply_gear_upgrades(inst)
	end

	inst.OnLoad = OnLoad
end

AddPrefabPostInit("wx78", WX78PostInit)

-- Illumination circuits cost hunger, and the Super-Illumination Circuit gives off more light.
-- Module prefabs read activatefn/deactivatefn from these shared definitions each time one spawns.
local ILLUMINATION_HUNGER_RATES = {
	light = 1.05, -- Illumination Circuit: +5% hunger drain
	light2 = 1.15, -- Super-Illumination Circuit: +15% hunger drain
}
local super_illumination_radius = GetModConfigData("wx78_super_illumination_radius") or 1

local function withLightRadiusMultiplier(multiplier, fn, ...)
	-- The base game's light_change is local, so scale the per-module radius it reads for this one call;
	-- this keeps WX-78's light and the Tinkering II beam in sync on both activate and deactivate
	local TUNING = GLOBAL.TUNING
	local base_radius = TUNING.WX78_LIGHT_RADIUS_PER_MODULE
	TUNING.WX78_LIGHT_RADIUS_PER_MODULE = base_radius * multiplier
	fn(...)
	TUNING.WX78_LIGHT_RADIUS_PER_MODULE = base_radius
end

for _, def in ipairs(GLOBAL.require("wx78_moduledefs").module_definitions) do
	local hunger_rate = ILLUMINATION_HUNGER_RATES[def.name]
	if hunger_rate ~= nil then
		local radius_multiplier = def.name == "light2" and super_illumination_radius or 1
		local original_activate = def.activatefn
		local original_deactivate = def.deactivatefn

		def.activatefn = function(inst, wx, ...)
			withLightRadiusMultiplier(radius_multiplier, original_activate, inst, wx, ...)
			if wx.components.hunger ~= nil then
				wx.components.hunger.burnratemodifiers:SetModifier(inst, hunger_rate, "illumination_hunger")
			end
		end

		def.deactivatefn = function(inst, wx, ...)
			withLightRadiusMultiplier(radius_multiplier, original_deactivate, inst, wx, ...)
			if wx.components.hunger ~= nil then
				wx.components.hunger.burnratemodifiers:RemoveModifier(inst, "illumination_hunger")
			end
		end
	end
end

if GetModConfigData("wx78_gear_indicator") ~= false then
	local WXGearBadge = require("widgets/wxgearbadge")

	AddClassPostConstruct("widgets/statusdisplays", function(self)
		if self.owner == nil or self.owner.prefab ~= "wx78" then
			return
		end

		self.wxgearbadge = self:AddChild(WXGearBadge(self.owner, WX78_MAX_GEARS))

		-- Combined Status adds its extra rows in its own post-construct, so place the badge once
		-- every mod has had a chance to build the status display
		self.inst:DoTaskInTime(0, function()
			self.wxgearbadge:PlaceBelowExtraRows(self)
		end)

		local old_set_ghost_mode = self.SetGhostMode
		function self:SetGhostMode(ghostmode, ...)
			old_set_ghost_mode(self, ghostmode, ...)
			if ghostmode then
				self.wxgearbadge:Hide()
			else
				self.wxgearbadge:Show()
			end
		end
	end)
end

-- Gears no longer restore stats when eaten; their value comes from the WX-78 upgrades
local function GearsPostInit(inst)
	if inst.components.edible ~= nil then
		inst.components.edible.healthvalue = 0
		inst.components.edible.hungervalue = 0
		inst.components.edible.sanityvalue = 0
	end
end

AddPrefabPostInit("gears", GearsPostInit)

-- Modify Pig King to always give a pigskin
local function PigKingPostInit(inst)
	local DEGREES = GLOBAL.DEGREES
	local TheCamera = GLOBAL.TheCamera
	local SpawnPrefab = GLOBAL.SpawnPrefab
	local old_on_accept = (inst.components.trader and inst.components.trader.onaccept) or function()
		return true
	end

	local function on_trade_for_pigskin(inst, item, giver)
		local x, y, z = inst.Transform:GetWorldPosition()
		y = 4.5

		local angle
		if giver ~= nil and giver:IsValid() then
			angle = 180 - giver:GetAngleToPoint(x, 0, z)
		else
			local down = TheCamera:GetDownVec()
			angle = math.atan2(down.z, down.x) / DEGREES
			giver = nil
		end
		local pigskin = SpawnPrefab("pigskin")
		pigskin.Transform:SetPosition(x, y, z)

		local speed = math.random() * 4 + 2
		angle = (angle + math.random() * 60 - 30) * DEGREES
		pigskin.Physics:SetVel(speed * math.cos(angle), math.random() * 2 + 8, speed * math.sin(angle))
	end

	local function OnAccept(inst, giver, item)
		old_on_accept(inst, giver, item)

		inst.sg:GoToState("cointoss")
		inst:DoTaskInTime(2 / 3, on_trade_for_pigskin, item, giver)
	end

	if inst.components.trader ~= nil then
		inst.components.trader.onaccept = OnAccept
	end
end

AddPrefabPostInit("pigking", PigKingPostInit)

-- Riding a beefalo keeps the rider warm; a shaved beefalo gives half as much
if beefalo_riding_insulation > 0 then
	AddComponentPostInit("temperature", function(self)
		local old_GetInsulation = self.GetInsulation
		function self:GetInsulation()
			local winter, summer = old_GetInsulation(self)
			local rider = self.inst.components.rider
			local mount = rider ~= nil and rider:GetMount() or nil
			if mount ~= nil and mount:HasTag("beefalo") then
				local shaved = mount.components.beard ~= nil and mount.components.beard.bits == 0
				winter = winter + (shaved and beefalo_riding_insulation / 2 or beefalo_riding_insulation)
			end
			return winter, summer
		end
	end)
end

-- Scale the treeguard chance on top of the world's Treeguards setting. That setting rewrites
-- TUNING.LEIF_PERCENT_CHANCE on world load (and again when the master shard syncs settings),
-- so wrap it rather than scaling the value once. Resetting to the stock chance first keeps
-- repeated calls from compounding, since the "default" level leaves the value untouched.
if treeguard_chance_multiplier ~= 1 then
	local worldsettings_overrides = GLOBAL.require("worldsettings_overrides")
	local original_liefs = worldsettings_overrides.Pre.liefs
	local stock_leif_chance = GLOBAL.TUNING.LEIF_PERCENT_CHANCE
	if original_liefs ~= nil then
		worldsettings_overrides.Pre.liefs = function(difficulty, ...)
			GLOBAL.TUNING.LEIF_PERCENT_CHANCE = stock_leif_chance
			original_liefs(difficulty, ...)
			GLOBAL.TUNING.LEIF_PERCENT_CHANCE = GLOBAL.TUNING.LEIF_PERCENT_CHANCE * treeguard_chance_multiplier
		end
	end
end

-- Each blow dart craft makes more than one dart. Base game recipes already exist when modmain runs.
if blowdart_craft_count > 1 then
	for _, recipe_name in ipairs({ "blowdart_pipe", "blowdart_fire", "blowdart_yellow", "blowdart_sleep" }) do
		local recipe = GLOBAL.AllRecipes[recipe_name]
		if recipe ~= nil then
			recipe.numtogive = blowdart_craft_count
		end
	end
end

-- Sleep and fire darts deal damage too, a bit less than a regular blow dart since they have other effects.
-- Damage lands before the dart's effect, so a sleep dart still puts its target to sleep.
local EFFECT_DART_DAMAGE = GLOBAL.TUNING.PIPE_DART_DAMAGE * 0.75
for _, prefab in ipairs({ "blowdart_sleep", "blowdart_fire" }) do
	AddPrefabPostInit(prefab, function(inst)
		if inst.components.weapon ~= nil then
			inst.components.weapon:SetDamage(EFFECT_DART_DAMAGE)
		end
	end)
end

-- Scale the naughtiness from killing innocent creatures. Values are read at kill time, so
-- rewriting the table here covers Krampus and the Rabbit King, which both read it.
if naughtiness_multiplier ~= 1 then
	for prefab, value in pairs(GLOBAL.NAUGHTY_VALUE) do
		GLOBAL.NAUGHTY_VALUE[prefab] = function(...)
			return GLOBAL.FunctionOrValue(value, ...) * naughtiness_multiplier
		end
	end
end

-- Recipes from other mods that use the deprecated AddRecipe only show up under the Mods crafting filter.
-- Also list them under the filter their old recipe tab pointed at. Deferred until every mod has loaded,
-- and skipped for any recipe that doesn't exist, so this is a no-op when those mods aren't enabled.
local EXTRA_RECIPE_FILTERS = {
	armor_stone = "ARMOUR", -- More Armor (workshop-1153998909)
	armor_bone = "ARMOUR", -- More Armor (workshop-1153998909)
	armor_repair_kit = "TOOLS", -- Armor Repair Kit (workshop-1155672829)
}

AddSimPostInit(function()
	for recipe_name, filter_name in pairs(EXTRA_RECIPE_FILTERS) do
		if GLOBAL.AllRecipes[recipe_name] ~= nil then
			AddRecipeToFilter(recipe_name, filter_name)
		end
	end
end)

-- Gilded Boomerang: a sturdier, harder-hitting boomerang made from a regular one
PrefabFiles = { "boomerang_gilded" }
table.insert(Assets, Asset("ATLAS", "images/inventoryimages/boomerang_gilded.xml"))
table.insert(Assets, Asset("IMAGE", "images/inventoryimages/boomerang_gilded.tex"))
RegisterInventoryItemAtlas(GLOBAL.resolvefilepath("images/inventoryimages/boomerang_gilded.xml"), "boomerang_gilded.tex")

AddRecipe2("boomerang_gilded",
	{ Ingredient("boomerang", 1), Ingredient("livinglog", 1), Ingredient("goldnugget", 2) },
	GLOBAL.TECH.SCIENCE_TWO,
	{ atlas = "images/inventoryimages/boomerang_gilded.xml", image = "boomerang_gilded.tex" },
	{ "WEAPONS" })

GLOBAL.STRINGS.NAMES.BOOMERANG_GILDED = "Gilded Boomerang"
GLOBAL.STRINGS.RECIPE_DESC.BOOMERANG_GILDED = "It always comes back, and hits harder."
GLOBAL.STRINGS.CHARACTERS.GENERIC.DESCRIBE.BOOMERANG_GILDED = "Heavier than it looks. It still comes back."

-- Initialize the modules
initThermalStone(AddPrefabPostInit)
