local function getStatus(id)
  local dmsg = { op = "getStatus" }
  rednet.send(id, utils.sed(dmsg), "minerDispatch")
end

local function doMine(id, startPos, endPos, depositPos)
  local dmsg = {
    op = "mine",
    startPos = startPos,
    endPos = endPos,
    depositPos = depositPos
  }
  rednet.send(id, utils.sed(dmsg), "minerDispatch")
end

local function requestChunkData(id, pos)
  local dmsg = {
    op = "chunkData",
    pos = utils.getChunkStart(pos),
  }
  rednet.send(id, utils.sed(dmsg), "minerDispatch")
end

local function getChunkData(pos)
  local chunkPos = utils.getChunkStart(pos)
  if not fs.isDir("/chunkData") then
    fs.makeDir("/chunkData")
  end
  local chunkFiles = fs.list("/chunkData/")
  local chunkPosName = utils.vec3.toString(chunkPos)
  for i = 1, #chunkFiles do
    if chunkFiles[i] == chunkPosName then
      local f = fs.open("/chunkData/" .. chunkPosName, "r")
      local contents = utils.desed(f.readAll())
      f.close()
      return contents
    end
  end
  -- TODO Make a request for chunk data here
  return nil
end

local function updateChunkData(dmsg, id)
  if dmsg.data == nil then
    print(("Failed chunkData update from %d because of '%s'"):format(id, dmsg.error))
    return false
  end
  if not fs.isDir("/chunkData") then
    fs.makeDir("/chunkData")
  end
  local chunkPosName = utils.vec3.toString(dmsg.pos)
  local f = fs.open("/chunkData/" .. chunkPosName, "w")
  f.write(utils.sed(dmsg.data))
  f.close()
  return true
end

slaves = {}
local function minerDispatch()
  local modem = peripheral.find("modem") or error("No modem attached!", 0)
  local modemName = peripheral.getName(modem)
  rednet.open(modemName)
  local miners = { rednet.lookup("minerDispatch") } --, "minerSlave") }
  for _, computer in pairs(miners) do
    print("Miner " .. computer)
    getStatus(computer)
  end
  print(#miners .. " miners online")
  while true do
    local id, msg = rednet.receive("minerDispatch")
    print(("Computer ID %d sent %s"):format(id, msg))
    local dmsg = utils.desed(msg)
    local case = {
      ["default"] = function(dmsg, id)
        warn(("Unknown dmsg operation '%s' from ID %d"):format(dmsg.op, id))
      end,
      ["getStatus"] = function(dmsg, id)
        print(textutils.serialize(dmsg))
        slaves[id] = dmsg
        if utils.any(dmsg.peripherals, function(v)
              return v == "geoScanner"
            end) then
          requestChunkData(id, dmsg.pos)
        end
      end,
      ["chunkData"] = updateChunkData,
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

minerDispatch()
