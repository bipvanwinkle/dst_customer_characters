local MakePlayerCharacter = require "prefabs/player_common"

local assets = {
  Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
}

-- Your character's stats
TUNING.ESCTEMPLATE_HEALTH = 151
TUNING.ESCTEMPLATE_HUNGER = 150
TUNING.ESCTEMPLATE_SANITY = 150

-- Custom starting inventory
TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.ESCTEMPLATE = {
  "blueprint",
  "flint",
  "flint",
  "twigs",
  "twigs",
}

local function print_table(table)
  for k, v in pairs(table) do
    print("Key: ", k, "Value: ", v)
  end
end

local start_inv = {}
for k, v in pairs(TUNING.GAMEMODE_STARTING_ITEMS) do
  start_inv[string.lower(k)] = v.ESCTEMPLATE
end
local prefabs = FlattenTree(start_inv, true)

-- When the character is revived from human
local function onbecamehuman(inst)
  print("I was just resurrected")
  -- Set speed when not a ghost (optional)
  inst.components.locomotor:SetExternalSpeedMultiplier(inst, "esctemplate_speed_mod", 1)
end

local function onbecameghost(inst)
  -- Remove speed modifier when becoming a ghost
  print("I just became a ghost")
  inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "esctemplate_speed_mod")
end

-- When loading or spawning the character
local function onload(inst)
  inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman)
  inst:ListenForEvent("ms_becameghost", onbecameghost)

  if inst:HasTag("playerghost") then
    onbecameghost(inst)
  else
    onbecamehuman(inst)
  end
end

-- This initializes for both the server and client. Tags can be added here.
local common_postinit = function(inst)
  -- Minimap icon
  inst.MiniMapEntity:SetIcon("esctemplate.tex")
end

local function OnDayComplete(self)
  local blueprint = SpawnPrefab("blueprint")
  -- local x, y, z = self.Transform:GetWorldPosition()
  -- blueprint.Transform:SetPosition(x, y + 2, z)
  -- local speed = 1 + math.random()
  -- local angle = math.random() * 2 * PI
  -- blueprint.Physics:SetVel(speed * math.cos(angle), 2 + math.random() * 3, speed * math.sin(angle))
  self.components.inventory:GiveItem(blueprint)
end

local function OnLearnRecipe(inst, data)
  -- TODO
  -- Create a blueprint with a specific recipe
  -- Place the blueprint in the inventory unless inventory is full
  --
  local blueprint = SpawnPrefab("blueprint")
  blueprint.components.teacher:SetRecipe(data.recipe)
  blueprint.components.named:SetName(STRINGS.NAMES[string.upper(data.recipe)] .. " " .. STRINGS.NAMES.BLUEPRINT)

  inst.components.inventory:GiveItem(blueprint)
  inst.components.sanity:DoDelta(10)
end

local function OnAttackOther(inst, data)
  print("Attacking somebody else")
  inst:PushEvent("oneatberry", { kind = "raspberry" })
end

local function OnEatBerry(inst, data)
  print("I ate a berry")
end

-- This initializes for the server only. Components are added here.
local master_postinit = function(inst)
  -- Set starting inventory
  inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

  -- choose which sounds this character will play
  inst.soundsname = "willow"

  -- Uncomment if "wathgrithr"(Wigfrid) or "webber" voice is used
  --inst.talker_path_override = "dontstarve_DLC001/characters/"

  inst:ListenForEvent("learnrecipe", function(inst, data) OnLearnRecipe(inst, data) end)
  inst:ListenForEvent("onunlockrecipe", function(inst, data) OnLearnRecipe(inst, data) end)
  inst:ListenForEvent("onattackother", function(inst, data) OnAttackOther(inst, data) end)
  inst:ListenForEvent("oneatberry", function(inst, data) OnEatBerry(inst, data) end)

  -- Stats
  inst.components.health:SetMaxHealth(TUNING.ESCTEMPLATE_HEALTH)
  inst.components.hunger:SetMax(TUNING.ESCTEMPLATE_HUNGER)
  inst.components.sanity:SetMax(TUNING.ESCTEMPLATE_SANITY)

  -- Perk
  inst:WatchWorldState("cycles", OnDayComplete)

  -- Damage multiplier (optional)
  inst.components.combat.damagemultiplier = 1

  -- Hunger rate (optional)
  inst.components.hunger.hungerrate = TUNING.WILSON_HUNGER_RATE

  inst.OnLoad = onload
  inst.OnNewSpawn = onload

end

return MakePlayerCharacter("esctemplate", prefabs, assets, common_postinit, master_postinit, prefabs)
