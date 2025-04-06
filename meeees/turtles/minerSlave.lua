local function selfStatus()
  return {
    op = "getStatus",
    pos = utils.vec3.new(gps.locate()),
    fuel = turtle.getFuelLevel(),
    peripherals = utils.map(peripheral.getNames(), peripheral.getType),
    label = os.getComputerLabel(),
  }
end

local function getStatus(dmsg, id)
  rednet.send(id, utils.sed(selfStatus()), "minerDispatch")
end

local function sendMineUpdate(dmsg, id)
  rednet.send(id, utils.sed(dmsg), "minerDispatch")
end

--[[
  This function is a coroutine that will mine out a given box
  Over the course of the program, it will yield with steps/fuel taken and total required
--]]
local function miningTask(startPos, endPos)

end

local function doMine(dmsg, id)
  --[[
    TODO:
     - Ensure we have enough fuel
     - Reach the closest corner of the bounding box defined by startPos/endPos
     - Mine through the box
     - Send status updates as we're mining
     - Return to the deposit location after mining
  --]]
  local startPos = dmsg.startPos
  local endPos = dmsg.endPos

  local height = endPos.y - startPos.y
  local depth = endPos.z - startPos.z
  local width = endPos.x - startPos.x

  -- Organized so opposite corners are +4 from each other
  local corners = {
    startPos,
    utils.vec3.new(startPos.x + width, startPos.y, startPos.z),
    utils.vec3.new(startPos.x + width, startPos.y + height, startPos.z),
    utils.vec3.new(startPos.x + width, startPos.y, startPos.z + depth),
    utils.vec3.new(startPos.x + width, startPos.y + height, startPos.z + depth),
    utils.vec3.new(startPos.x, startPos.y + height, startPos.z + depth),
    utils.vec3.new(startPos.x, startPos.y, startPos.z + depth),
    utils.vec3.new(startPos.x, startPos.y + height, startPos.z),
  }
  local curPos = utils.vec3.new(gps.locate())
  local distances = utils.map(corners, function(v)
    return utils.manhattanDistance(v, curPos)
  end)
  local lowest = 1
  for i = 2, #distances do
    if distances[i] < distances[lowest] then
      lowest = i
    end
  end

  utils.moveTo(corners[lowest], true)

  local mineTask = coroutine.create(miningTask)
  while true do
    local taken, required = mineTask.resume(corners[lowest], corners[((lowest + 3) % 8) + 1])
    sendMineUpdate({
      op = "mine",
      progress = taken,
      total = required,
      startPos = startPos,
      endPos = endPos,
      pos = utils.vec3.new(gps.locate())
    })
    if taken == required then
      break
    end
  end
end

local function getChunkData(dmsg, id)
  local scanner = peripheral.find("geoScanner")
  if scanner == nil then
    rednet.send(id, utils.sed({
      op = "chunkData",
      data = nil,
      pos = dmsg.pos,
      error = "No geoScanner peripheral!",
    }), "minerDispatch")
    return
  end
  utils.moveTo(dmsg.pos)
  rednet.send(id, utils.sed({
    op = "chunkData",
    pos = dmsg.pos,
    data = scanner.chunkAnalyze(),
  }), "minerDispatch")
end

local function minerSlave()
  local initialStatus = selfStatus()
  local modem = peripheral.find("modem") or error("No modem attached!", 0)
  local modemName = peripheral.getName(modem)
  rednet.open(modemName)
  -- We host here because slaves actually act more like a server than a client
  -- They await tasks indefinitely until the Dispatcher tells them to do something
  if utils.any(initialStatus.peripherals, function(v)
        return v == "geoScanner"
      end) then
    rednet.host("minerDispatch", "minerScout")
  else
    rednet.host("minerDispatch", "minerSlave")
  end
  print(textutils.serialize(initialStatus))
  print("Awaiting tasking...")
  while true do
    local id, msg = rednet.receive("minerDispatch")
    print(("Computer ID %d sent %s"):format(id, msg))
    local dmsg = utils.desed(msg)
    local case = {
      ["default"] = function(dmsg, id)
        warn(("Unknown dmsg operation '%s' from ID %d"):format(dmsg.op, id))
      end,
      ["getStatus"] = getStatus,
      ["chunkData"] = getChunkData,
      ["mine"] = doMine,
    }
    local f = case[dmsg.op]
    if (f) then
      f(dmsg, id)
    else
      case["default"](dmsg, id)
    end
  end
end

minerSlave()
