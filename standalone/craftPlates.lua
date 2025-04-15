local iUtils = require("invUtils")

local defaultPlateGoal = 16
local defaultMinIngots = 64

local function plate(plate, ingot, goalPlates, minIngots)
  if ingot == nil or ingot == "" then
    ingot = string.gsub(plate, "plate", "ingot")
  end
  if goalPlates == nil then
    goalPlates = defaultPlateGoal
  end
  if minIngots == nil then
    minIngots = defaultMinIngots
  end
  return {
    plate = plate,
    ingot = ingot,
    goalPlates = goalPlates,
    minIngots = minIngots
  }
end

-- Entries with 0 are effectively disabled
--  Entries with empty ingot will default to replace "plate" with "ingot"
local plateList = {
  plate("ad_astra:desh_plate"),
  plate("ad_astra:ostrum_plate"),
  plate("ad_astra:calorite_plate"),
  plate("immersiveengineering:plate_aluminum"),
  plate("immersiveengineering:plate_uranium", "mekanism:ingot_uranium"),
  plate("thermal:iron_plate", "minecraft:iron_ingot", 64, 128),
  plate("thermal:gold_plate", "minecraft:gold_ingot", 64, 128),
  plate("thermal:copper_plate", "minecraft:copper_ingot", 64, 128),
  plate("thermal:netherite_plate", "minecraft:netherite_ingot", 0),
  plate("thermal:signalum_plate", "", 0),
  plate("thermal:lumium_plate", "", 0),
  plate("thermal:enderium_plate", "", 8),
  plate("thermal:steel_plate", "", 64, 128),
  plate("thermal:rose_gold_plate", "", 8),
  plate("thermal:tin_plate"),
  plate("thermal:lead_plate"),
  plate("thermal:silver_plate"),
  plate("thermal:nickel_plate"),
  plate("thermal:bronze_plate"),
  plate("thermal:electrum_plate"),
  plate("thermal:invar_plate", "", 8),
  plate("thermal:constantan_plate", "", 8),
  plate("thermal_extra:soul_infused_plate", "", 0),
  plate("thermal_extra:shellite_plate", "", 0),
  plate("thermal_extra:twinite_plate", "", 0),
  plate("thermal_extra:dragonsteel_plate", "", 0),
  plate("kubejs:plate_endsteel", "kubejs:endsteel_ingot", 8),
  plate("kubejs:plate_darksteel", "kubejs:darksteel_ingot", 8),
  plate("kubejs:plate_diamond", "minecraft:diamond", 8),
  plate("kubejs:plate_emerald", "minecraft:emerald", 8),
  plate("kubejs:plate_lapis", "minecraft:lapis_lazuli", 8),
  plate("kubejs:plate_quartz", "minecraft:quartz"),
  plate("kubejs:osmium_plate", "mekanism:ingot_osmium"),
  plate("createaddition:zinc_sheet", "create:zinc_ingot"),
  plate("ftbic:iridium_plate", "ftbic:iridium_ingot", 8),
  plate("thermalendergy:prismalium_plate", "", 0),
  plate("thermalendergy:melodium_plate", "", 0),
  plate("thermalendergy:stellarium_plate", "", 0),
}

local function findPlate(name)
  local res = {}
  for _, plate in pairs(plateList) do
    if string.find(plate.plate, name) ~= nil then
      res[#res + 1] = plate
    end
  end
  return res
end

local CraftStatus = {
  Skipped = "Skipped",
  AlreadyComplete = "AlreadyComplete",
  MissingMats = "MissingMats",
  Partial = "Partial",
  Full = "Full"
}
local CS = CraftStatus

local function n0(v)
  return v or 0
end

local function item(name, count)
  return {
    name = name,
    count = count,
  }
end

local function shortItem(name)
  return string.sub(name, string.find(name, ":") + 1)
end

local function itemStr(item)
  return "(" .. shortItem(item.name) .. ", " .. item.count .. ")"
end



local function craftStatus(item, status, goal, toCraft, missingMats)
  return {
    item = item,
    status = status,
    goal = goal,
    toCraft = toCraft,
    missingMats = missingMats
  }
end

local function craftStatusStr(status)
  local reqs = ""
  if status.missingMats ~= nil then
    reqs = "\nMissing: "
    for ind, i in pairs(status.missingMats) do
      reqs = reqs .. itemStr(i)
      if ind < #status.missingMats then
        reqs = reqs .. ", "
      end
    end
  end
  return "{ " ..
      shortItem(status.item) .. ": " .. "Crafting " ..
      n0(status.toCraft) .. " of " ..
      n0(status.goal) .. reqs .. " }"
end

local function calcPlatesToCraft(list)
  local lectern, invTable = iUtils.getCache()
  local res = {}

  for _, p in pairs(plateList) do
    local goal = p.goalPlates
    local plate = p.plate

    if goal == 0 then
      res[plate] = craftStatus(plate, CraftStatus.Skipped, goal)
    else
      local current = invTable[plate]
      local toMake = 0
      if current == nil then
        toMake = goal
      elseif current.count < goal then
        toMake = goal - current.count
      end

      -- negative ingots available - we are below minimum, no crafting
      -- ingots available < toMake - we can craft some but not all of the goal
      if toMake > 0 then
        local ingots = invTable[p.ingot]
        local ingotsAvailable = 0

        if ingots == nil then
          ingotsAvailable = -toMake
        else
          ingotsAvailable = math.min(toMake, ingots.count - p.minIngots)
        end

        local status, missing
        if ingotsAvailable == goal then
          status = CraftStatus.Full
        else
          if ingotsAvailable > 0 then
            toMake = ingotsAvailable
            status = CraftStatus.Partial
          else
            toMake = 0
            status = CraftStatus.MissingMats
          end
          local needed = goal - toMake
          if ingotsAvailable < 0 then
            needed = needed + -ingotsAvailable
          end

          missing = { item(p.ingot, needed) }
        end
        res[plate] = craftStatus(plate, status, goal, toMake, missing)
      else
        res[plate] = craftStatus(plate, CraftStatus.AlreadyComplete, goal)
      end
    end
  end

  return res
end

local function craftPlates(plateName, goal, force)
  local plate = findPlate(plateName)
  if #plate ~= 1 then
    error("Could not match plate type!")
    return
  end

  plate = plate[1]

  print("Crafting " .. goal .. " " .. plate.plate)

  local roller = iUtils.getRoller()
  local rollerInv = roller.list()
  local lectern, cache = iUtils.getCache()

  if rollerInv[1] ~= nil then
    error("Roller is busy!")
    return
  end

  if rollerInv[2] ~= nil then
    print("Emptying roller - " .. rollerInv[2].name)
    iUtils.moveItems(roller, lectern, rollerInv[2].name, rollerInv[2].count)
  end

  print("Looking for " .. plate.ingot)

  local ingots = cache[plate.ingot]
  local ingotCount = ingots.count
  if not force then
    ingotCount = ingotCount - plate.minIngots
  end

  if ingotCount < goal then
    error("Not enough ingots to complete! Need " .. (goal - ingotCount) .. " more.")
    return
  end

  local batches = math.ceil(goal / 64)
  print("Batch Count: " .. batches)
  for i = 1, batches do
    print("Batch " .. i .. ", moving items to roller")
    local toMove = math.min(64, goal)
    _, cache = iUtils.getCache()
    iUtils.moveItems(lectern, roller, plate.ingot, toMove, cache)
    local sleepTime = toMove * 6
    print("Waiting " .. sleepTime .. " for crafting to complete...")
    os.sleep(sleepTime)
    local check = roller.list()[1]
    while check ~= nil do
      sleepTime = check.count * 6
      print("Roller still busy, waiting another " .. sleepTime)
      os.sleep(sleepTime)
      check = roller.list()[1]
    end
    print("Batch complete! Moving plates back to storage")
    iUtils.moveItems(roller, lectern, plate.plate, toMove)
  end
end


local function printStatuses(resultTable)
  local groups = {}

  groups[CS.Skipped] = {}
  groups[CS.AlreadyComplete] = {}
  groups[CS.Full] = {}
  groups[CS.Partial] = {}
  groups[CS.MissingMats] = {}

  for _, s in pairs(resultTable) do
    groups[s.status][#groups[s.status] + 1] = s
  end

  local function header(type)
    local vals = groups[type]
    return "-- " .. type .. " (" .. #vals .. ") --"
  end

  local function basicPrint(type)
    print(header(type))
    local vals = groups[type]
    local res = ""
    for i = 1, #vals do
      local v = vals[i]
      res = res .. shortItem(v.item)
      if v.goal ~= 0 then
        res = res .. ": " .. v.goal
      end
      if i ~= #vals then
        res = res .. ", "
      end
    end
    print(res)
  end

  local function detailedPrint(type)
    print(header(type))
    local vals = groups[type]
    for _, v in pairs(vals) do
      print(craftStatusStr(v))
    end
  end

  basicPrint(CS.Skipped)
  basicPrint(CS.AlreadyComplete)
  detailedPrint(CS.Full)
  detailedPrint(CS.Partial)
  detailedPrint(CS.MissingMats)
end

local function c0(i)
  if i == nil then
    return 0
  end
  return i.count or 0
end

if arg[1] == "list" then
  local list = plateList
  local _, cache = iUtils.getCache()
  if arg[2] ~= nil then
    list = findPlate(arg[2])
  end

  for _, p in pairs(list) do
    print(string.format("%s (%d), %d craftable", shortItem(p.plate), c0(cache[p.plate]), c0(cache[p.ingot]) - p
      .minIngots))
  end
  return
end



if #arg ~= 2 and #arg ~= 3 then
  print("Usage: " .. arg[0] .. "<plate> <amt> (f)")
  return
end

craftPlates(arg[1], tonumber(arg[2]), arg[3] == "f")

-- printStatuses(calcPlatesToCraft(plateList))
