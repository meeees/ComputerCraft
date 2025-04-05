local torchDist = 20

-- defaulting values.. is this the best way to do this? lol.
local function def(val, default)
  if val == nil then
    return default
  end
  return val
end

local function reloadUtils()
  _G.utils = dofile("/meeees/utils/utils.lua")
  print("Utils reloaded")
end

local function pullCode(reload)
  reload = def(reload, true)
  os.run({}, "/setup.lua", "code")
  if reload then
    reloadUtils()
  end
end

local function map(t, func)
  local result = {}
  for i, v in pairs(t) do
    result[i] = func(v)
  end
  return result
end

local function any(t, func)
  for i, v in pairs(t) do
    if func(v) then
      return true
    end
  end
  return false
end

local function all(t, func)
  for i, v in pairs(t) do
    if not func(v) then
      return false
    end
  end
  return true
end

local function select(t, func)
  local result = {}
  for i, v in pairs(t) do
    if func(v) then
      result[i] = t[i]
    end
  end
  return result
end

--#region Types
local function v2_new(x, y)
  return { x = x, y = y }
end

local vec2 = {
  new = function(x, y)
    return v2_new(x, y)
  end,
  add = function(v1, v2)
    return v2_new(v1.x + v2.x, v1.y + v2.y)
  end,
  neg = function(v)
    return v2_new(-v.x, -v.y)
  end,
  sub = function(v1, v2)
    return v2_new(v1.x - v2.x, v1.y - v2.y)
  end,
  scale = function(v1, s)
    return v2_new(v1.x * s, v1.y * s)
  end,
  one = function()
    return v2_new(1, 1)
  end,
  zero = function()
    return v2_new(0, 0)
  end,
  toString = function(v)
    return "(" .. v.x .. ", " .. v.y .. ")"
  end
}

local function v3_new(x, y, z)
  return { x = x, y = y, z = z }
end

local vec3 = {
  new = function(x, y, z)
    return v3_new(x, y, z)
  end,
  add = function(v1, v2)
    return v3_new(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
  end,
  neg = function(v)
    return v3_new(-v.x, -v.y, -v.z)
  end,
  sub = function(v1, v2)
    return v3_new(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
  end,
  scale = function(v, s)
    return v3_new(v.x * s, v.y * s, v.z * s)
  end,
  one = function()
    return v3_new(1, 1, 1)
  end,
  zero = function()
    return v3_new(0, 0, 0)
  end,
  toString = function(v)
    return "(" .. v.x .. ", " .. v.y .. ", " .. v.z .. ")"
  end
}

local Dir = {
  [0] = "North",
  [1] = "East",
  [2] = "South",
  [3] = "West"
}

local DirToVec = {
  [0] = vec3.new(0, 0, -1),
  [1] = vec3.new(1, 0, 0),
  [2] = vec3.new(0, 0, 1),
  [3] = vec3.new(-1, 0, 0),
}


--#endregion

local function placeFrom(slot, back, down)
  back = def(back, false)
  down = def(down, false)
  turtle.select(slot)
  if back then
    turtle.back()
  end
  if down then
    turtle.placeDown()
  else
    turtle.place()
  end
  if back then
    turtle.forward()
  end
end


--#region Inventories

local function getItemFrom(position, type, amt)
  local x, y, z = gps.locate()
  local myPos = { x = x, y = y, z = z }
end

local function searchInventory(itemName)
  local slots = {}
  local total = 0
  for i = 1, 16 do
    if turtle.getItemDetail(i) ~= nil and turtle.getItemDetail(i).name == itemName then
      local c = turtle.getItemCount(i)
      slots[i] = c
      total = total + c
    end
  end
  return slots, total
end

--#endregion

--#region FuelCalcs
local function manhattanDistance(from, to)
  local x = math.abs(from.x - to.x)
  local y = math.abs(from.y - to.y)
  local z = math.abs(from.z - to.z)
  return x + y + z
end


local function getAvailableFuel()
  local slots, count = searchInventory("minecraft:charcoal")
  local charcoalValue = 80
  count = count * charcoalValue
  return slots, count
end

local function getFuelTo(goal)
  goal = def(goal, 40)
  local current = turtle.getFuelLevel()
  if current >= goal then
    return true
  end
  local slots, available = getAvailableFuel()
  if current + available < goal then
    print("Turtle does not have enough charcoal for " .. goal)
    return false
  end
  for s, c in pairs(slots) do
    while turtle.getFuelLevel() < goal do
      turtle.select(s)
      turtle.refuel(1)
      c = c - 1
      if c == 0 then
        break
      end
    end
    if turtle.getFuelLevel() >= goal then
      break
    end
  end
  return true
end

local function calcMissingFuel(goal)
  local current = turtle.getFuelLevel()
  if current >= goal then
    return 0
  end
  local slots, available = getAvailableFuel()
  local remaining = math.max(0, goal - (current + available))
  return remaining
end
--#endregion


--#region Serialization

-- Deserailize function for arbitrary lua data
local function desed(val)
  local case = {
    ["t"] = function(v)
      local next = v:find(":")
      local items = tonumber(v:sub(2, next - 1))
      local current = next + 1
      local ret = {}
      for i = 1, items do
        local nk, l = desed(v:sub(current, #v))
        current = current + l
        local nv, l2 = desed(v:sub(current, #v))
        current = current + l2
        ret[nk] = nv
      end
      return ret, current - 1
    end,
    ["s"] = function(v)
      local sep = v:find(":")
      local count = tonumber(v:sub(2, sep - 1))
      return v:sub(sep + 1, count + sep), count + sep
    end,
    ["i"] = function(v)
      local next = v:find(":")
      return tonumber(v:sub(2, next - 1)), next
    end,
    ["b"] = function(v)
      local cond = tonumber(v:sub(2, 2))
      return cond == 1, 2
    end,
    ["n"] = function(v)
      return nil, 1
    end,
    ["default"] = function(v)
      error("Unknown deserialize value " .. v:sub(1, 1), 0)
      return nil, 0
    end,
  }
  local f = case[val:sub(1, 1)]
  if (f) then
    return f(val)
  else
    return case["default"](val)
  end
end

--#region Movement

local function getChunkStart(pos)
  return vec3.new(
    bit.band(pos.x, bit.bnot(15)),
    pos.y,
    bit.band(pos.z, bit.bnot(15))
  )
end

local bannedMines = { "computercraft", "chest", "shulker" }
-- returns movement success and direction of move
local function allowMining(blockPresent, blockData)
  if not blockPresent then
    return true
  end
  for _, val in pairs(bannedMines) do
    if string.find(blockData.name, val) ~= nil then
      return false
    end
  end
  return true
end

local function move(d, dig)
  dig = def(dig, false)
  for _ = 0, d do
    if not turtle.forward() then
      if dig then
        turtle.dig()
        turtle.forward()
      else
        print("Turtle could not reach goal")
        return false
      end
    end
  end
  return true
end

local function setFacing(dir)
  settings.set("facing", dir)
  settings.save()
end

local function getFacing()
  return settings.get("facing")
end

local function dirBetween(sP, eP)
  local dir = -1
  if sP.z > eP.z then
    dir = 0
  elseif sP.x < eP.x then
    dir = 1
  elseif sP.z < eP.z then
    dir = 2
  elseif sP.x > eP.x then
    dir = 3
  end
  return dir
end

local function calcFacing(allowMine)
  allowMine = def(allowMine, true)
  if not getFuelTo(1) then
    print("No fuel! Please add charcoal and try again")
    return false, -1
  end

  local sP = vec3.new(gps.locate())
  if not turtle.forward() then
    if not allowMine or not allowMining(turtle.inspect()) then
      print("Turtle could not move!")
      return false, -1
    end
    turtle.dig()
    turtle.forward()
  end

  local eP = vec3.new(gps.locate())
  local dir = dirBetween(sP, eP)

  if dir ~= -1 then
    setFacing(dir)
    return true, dir
  end

  return false, -1
end

local function left()
  turtle.turnLeft()
  setFacing((getFacing() - 1) % 4)
end

local function right()
  turtle.turnRight()
  setFacing((getFacing() + 1) % 4)
end

local function turnAround()
  turtle.turnLeft()
  turtle.turnLeft()
  setFacing((getFacing() + 2) % 4)
end

local function lookAt(pos)
  local goalDir = dirBetween(vec3.new(gps.locate()), pos)
  if goalDir == -1 then
    return
  end
  while getFacing() ~= goalDir do
    left()
  end
end

local function stepForward(miningAllowed)
  if not turtle.forward() then
    if not miningAllowed or not allowMining(turtle.inspect()) then
      return false
    end
    turtle.dig()
    turtle.forward()
  end
  return true, getFacing()
end

local function stepUp(miningAllowed)
  if not turtle.up() then
    if not miningAllowed or not allowMining(turtle.inspectUp()) then
      return false
    end
    turtle.digUp()
    turtle.up()
  end
  return true
end

local function stepDown(miningAllowed)
  if not turtle.down() then
    if not miningAllowed or not allowMining(turtle.inspectDown()) then
      return false
    end
    turtle.digDown()
    turtle.down()
  end
  return true
end

local function moveTo(pos, miningAllowed)
  miningAllowed = def(miningAllowed, true)
  local myPos = vec3.new(gps.locate())
  local cost = manhattanDistance(myPos, pos)
  local offset = vec3.sub(pos, myPos)
  local slots, available = getAvailableFuel()
  if cost > turtle.getFuelLevel() + available then
    return false
  end

  local hasFacing = getFacing() ~= nil
  if not hasFacing then
    hasFacing, _ = calcFacing()
  end

  if not hasFacing then
    print("Could not determine direction!")
    return
  end

  if cost == 0 then
    return true
  end

  getFuelTo(cost)

  lookAt(pos)

  local progress = true
  local dir
  while cost > 0 and progress do
    if offset.x == 0 and offset.z == 0 then
      if offset.y > 0 then
        progress = stepUp(miningAllowed)
        offset.y = offset.y - 1
      elseif offset.y < 0 then
        progress = stepDown(miningAllowed)
        offset.y = offset.y + 1
      end
    else
      progress, dir = stepForward(miningAllowed)
      if progress then
        offset = vec3.sub(offset, DirToVec[dir])
        if dir % 2 == 0 then
          if offset.z == 0 then
            lookAt(pos)
          end
        else
          if offset.x == 0 then
            lookAt(pos)
          end
        end
      end
    end
    if progress then
      cost = cost - 1
      -- otherwise try to go around somehow?
    end
  end

  if not progress then
    print("Error! Turtle could not reach goal!")
    return false
  end

  return true
end


local function tunnelOne()
  move(1, true)
end

--#endregion


-- Serialize function for arbitrary lua data
local function sed(val)
  local case = {
    ["table"] = function(v)
      local ret = ":"
      -- on tables the #table operator only works if the table is
      --  array-like, therefore we must count on our own
      local count = 0
      for a, b in pairs(v) do
        ret = ret .. sed(a) .. sed(b)
        count = count + 1
      end
      return "t" .. tostring(count) .. ret
    end,
    ["string"] = function(v)
      return "s" .. #v .. ":" .. v
    end,
    ["number"] = function(v)
      return "i" .. tostring(v) .. ":"
    end,
    ["boolean"] = function(v)
      return "b" .. tostring((v and 1 or 0))
    end,
    ["nil"] = function(v)
      return "n"
    end,
    ["default"] = function(v)
      error("Cannot serialize type '" .. type(v) .. "'!", 0)
      return nil
    end,
  }
  local f = case[type(val)]
  if (f) then
    return f(val)
  else
    return case["default"](val)
  end
end

--#endregion

---@class Utils
utils = {
  def = def,
  vec2 = vec2,
  vec3 = vec3,
  Dir = Dir,
  DirToVec = DirToVec,
  map = map,
  any = any,
  all = all,
  select = select,
  getChunkStart = getChunkStart,
  reloadUtils = reloadUtils,
  pullCode = pullCode,
  move = move,
  moveTo = moveTo,
  lookAt = lookAt,
  dirBetween = dirBetween,
  getFacing = getFacing,
  setFacing = setFacing,
  calcFacing = calcFacing,
  getFuelTo = getFuelTo,
  left = left,
  right = right,
  turnAround = turnAround,
  tunnelOne = tunnelOne,
  placeFrom = placeFrom,
  torchDist = torchDist,
  manhattanDistance = manhattanDistance,
  searchInventory = searchInventory,
  getAvailableFuel = getAvailableFuel,
  calcMissingFuel = calcMissingFuel,
  getItemFrom = getItemFrom,
  sed = sed,
  desed = desed,
}

return utils
