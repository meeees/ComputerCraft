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

local function getTaskFromChunk(chunkPos)
  local chunkStart = utils.getChunkStart(chunkPos)
  if utils.vec3.eq(chunkStart, utils.getChunkStart(utils.vec3.new(gps.locate()))) then
    return nil
  end
  return {
    utils.vec3.new(chunkStart.x, 65, chunkStart.z),
    utils.vec3.new(chunkStart.x + 15, -63, chunkStart.z + 15)
  }
end

local function dispatchMiningTask(task, availableMiners)
  -- take total y difference
  -- divide over number of miners
  -- chunk task into those sized pieces by y
  -- send mine request to all miners on list
  -- return true if this all succeeds, false if it fails for some reason
  return true
end

slaves = {}
local function minerDispatch()
  local dispatcher_loc = utils.vec3.new(gps.locate())
  local chunk_prio = {}

  local modem = peripheral.find("modem") or error("No modem attached!", 0)
  local modemName = peripheral.getName(modem)
  rednet.open(modemName)
  local miners = { rednet.lookup("minerDispatch") } --, "minerSlave") }
  for _, computer in pairs(miners) do
    print("Slave " .. computer)
    getStatus(computer)
  end
  print(#miners .. " slaves online")
  local availableMinerIds = {}
  local miningTasks = {}
  while true do
    local id, msg = rednet.receive("minerDispatch", 1)
    if not id then
      -- This means miner dispatch timed out.
      if #miningTasks > 0 and #availableMinerIds > 0 then
        local task = table.remove(miningTasks)
        if dispatchMiningTask(task, availableMinerIds) then
          availableMinerIds = {}
        end
      end
    else
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
          else
            table.insert(availableMinerIds, id)
            local temp_pos = utils.vec3.new(dmsg.pos.x, 70, dmsg.pos.z)
            local chunk_pos = utils.getChunkStart(temp_pos)
            table.insert(chunk_prio, chunk_pos)
            local adjacent = utils.getAdjacentChunks(chunk_pos)
            for i = 1, #adjacent do
              table.insert(chunk_prio, adjacent[i])
            end
            table.sort(chunk_prio, function(a, b)
              return utils.manhattanDistance(dispatcher_loc, a) > utils.manhattanDistance(dispatcher_loc, b)
            end)
          end
        end,
        ["chunkData"] = function(dmsg, id)
          updateChunkData(dmsg, id)
          local task = getTaskFromChunk(dmsg.pos)
          if task then
            -- Insert at the start because we take from the end
            -- Chunks were prio'd based on distance so we're keeping that
            table.insert(miningTasks, 1, task)
          end
          if #chunk_prio > 0 then
            local prio_chunk = table.remove(chunk_prio)
            requestChunkData(id, prio_chunk)
          end
        end,
        ["mine"] = function(dmsg, id)
          print(("Miner %d at %d / %d progress on %s - %s"):format(
            id, dmsg.progress, dmsg.total, utils.vec3.toString(dmsg.startPos),
            utils.vec3.toString(dmsg.endPos)
          ))
          if dmsg.progress == dmsg.total then
            table.insert(availableMinerIds, id)
          end
        end,
      }
      local f = case[dmsg.op]
      if (f) then
        f(dmsg, id)
      else
        case["default"](dmsg, id)
      end
    end
  end
end

minerDispatch()
