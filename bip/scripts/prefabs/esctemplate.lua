local MakePlayerCharacter = require "prefabs/player_common"
local SourceModifierList = require("util/sourcemodifierlist")

local assets = {
  Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
}

-- Your character's stats
TUNING.ESCTEMPLATE_HEALTH = 151
TUNING.ESCTEMPLATE_HUNGER = 150
TUNING.ESCTEMPLATE_SANITY = 150

TUNING.MEMORY_FOG = {
  SANITY = {
    LEVEL_ONE = -.01,
    LEVEL_TWO = -.05,
    LEVEL_THREE = -.10
  }
}

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

--TODO make it so that learning from the science machine also remove the sanity penalty
local function OnLearnRecipe(inst, data)
  print("I learned something")
  local blueprint = SpawnPrefab("blueprint")
  blueprint.components.teacher:SetRecipe(data.recipe)
  blueprint.components.named:SetName(STRINGS.NAMES[string.upper(data.recipe)] .. " " .. STRINGS.NAMES.BLUEPRINT)

  inst.components.inventory:GiveItem(blueprint)
  inst.components.sanity:DoDelta(10)

  inst.components.timer:StopTimer("memory_fog")
  inst.components.timer:StartTimer("memory_fog",
    TUNING.SEG_TIME * (TUNING.DAY_SEGS_DEFAULT + TUNING.DUSK_SEGS_DEFAULT + TUNING.NIGHT_SEGS_DEFAULT) * 3)
  inst.components.sanity.externalmodifiers:RemoveModifier("memory_fog")
  inst.memory_fog["level"] = "LEVEL_ONE"

  print_table(inst.memory_fog.learn_log)
  inst.memory_fog.learn_log[data.recipe] = { cycle = TheWorld.state.cycles, time = TheWorld.state.time }
  print_table(inst.memory_fog.learn_log[data.recipe])
end

local function OnAttackOther(inst, data)
  print("Attacking somebody else")
  print("GetTime", GetTime())
  print("GetTickTime", GetTickTime())
  print("GetStaticTime", GetStaticTime())
  print("GetTick", GetTick())
  print("GetStaticTick", GetStaticTick())
  print("GetTimeReal", GetTimeReal())
  print("GetTimeRealSeconds", GetTimeRealSeconds())
  print("The World Cycles", TheWorld.state.cycles)
  print("The World Time", TheWorld.state.time)
  inst:PushEvent("oneatberry", { kind = "raspberry" })
end

-- Just a random event listener to test that custom events work
local function OnEatBerry(inst, data)
  print("I ate a berry")
end

-- local function OnClockSegmentChanged(inst, data)
--   print("Tick tock")
-- end

local function OnMemoryFog(inst, data)
  if data.name == "memory_fog" then
    print("I haven't learned anything in a while")
    print("My current memory fog level is ", inst.memory_fog.level)
    if inst.memory_fog.level == "LEVEL_ONE" then
      inst.memory_fog.level = "LEVEL_TWO"
    elseif inst.memory_fog.level == "LEVEL_TWO" then
      inst.memory_fog.level = "LEVEL_THREE"
    end

    local new_sanity_debuff = TUNING.MEMORY_FOG.SANITY[inst.memory_fog.level]
    inst.components.sanity.externalmodifiers:SetModifier('memory_fog', new_sanity_debuff)
    inst.components.timer:StartTimer("memory_fog",
      TUNING.SEG_TIME * (TUNING.DAY_SEGS_DEFAULT + TUNING.DUSK_SEGS_DEFAULT + TUNING.NIGHT_SEGS_DEFAULT) * 3)
  end
end

local function GetOnLoad(inst)
  local old_OnLoad = inst.OnLoad
  local function new_OnLoad(inst, data, ...) -- "..." is used to also load also all other parameters we are currently not interested in, if there are any.
    if data ~= nil then -- if something was loaded
      if data.memory_fog == nil then
        inst.memory_fog = { level = "LEVEL_ONE", learn_log = {} }
      else
        inst.memory_fog = data.memory_fog
      end
      if data.memory_fog.learn_log == nil then
        inst.memory_fog.learn_log = {}
      end
    else
      inst.memory_fog = { level = "LEVEL_ONE", learn_log = {} }
    end
    local new_sanity_debuff = TUNING.MEMORY_FOG.SANITY[inst.memory_fog.level]
    inst.components.sanity.externalmodifiers:SetModifier('memory_fog', new_sanity_debuff)
    inst.components.timer:StartTimer("memory_fog",
      TUNING.SEG_TIME * (TUNING.DAY_SEGS_DEFAULT + TUNING.DUSK_SEGS_DEFAULT + TUNING.NIGHT_SEGS_DEFAULT) * 3)
    if old_OnLoad ~= nil then
      return old_OnLoad(inst, data, ...)
    end
  end

  return new_OnLoad
end

local function GetOnSave(inst)
  local old_OnSave = inst.OnSave
  local function new_OnSave(inst, data, ...)
    data.memory_fog = inst.memory_fog -- simply add your data (currently within the instance) to the data list
    if old_OnSave ~= nil then old_OnSave(inst, data, ...) end -- call the old, if there is one. no need to return data
  end

  return new_OnSave
end

-- This initializes for the server only. Components are added here.
local master_postinit = function(inst)
  -- Set starting inventory
  inst.starting_inventory = start_inv[TheNet:GetServerGameMode()] or start_inv.default

  -- choose which sounds this character will play
  inst.soundsname = "willow"

  -- Uncomment if "wathgrithr"(Wigfrid) or "webber" voice is used
  --inst.talker_path_override = "dontstarve_DLC001/characters/"

  -- inst:ListenForEvent("learnrecipe", function(inst, data) OnLearnRecipe(inst, data) end)
  inst:ListenForEvent("unlockrecipe", function(inst, data) OnLearnRecipe(inst, data) end)
  inst:ListenForEvent("onattackother", function(inst, data) OnAttackOther(inst, data) end)
  inst:ListenForEvent("oneatberry", function(inst, data) OnEatBerry(inst, data) end)
  inst:ListenForEvent("timerdone", function(inst, data) OnMemoryFog(inst, data) end)


  -- Couldn't get this to work 👇
  -- inst:ListenForEvent("clocksegschanged", function(inst, data) OnClockSegmentChanged(inst, data) end)

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

  inst.OnLoad = GetOnLoad(inst)
  inst.OnSave = GetOnSave(inst)
  inst.OnNewSpawn = GetOnLoad(inst)
end

return MakePlayerCharacter("esctemplate", prefabs, assets, common_postinit, master_postinit, prefabs)
