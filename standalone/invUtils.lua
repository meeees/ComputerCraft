local storeUrl = "ars_nouveau:storage_lectern_1"
local rollerUrl = "ftbic:roller_0"
local extruderUrl = "ftbic:extruder_1"




local function noInv()
  return error("No inventory attached!", 0)
end

local function getLectern()
  return peripheral.wrap(storeUrl) or noInv()
end

local function getRoller()
  return peripheral.wrap(rollerUrl) or noInv()
end

local function toLookup(invTable)
  local res = {}
  for slot, content in pairs(invTable) do
    local entry = res[content.name] or { name = content.name, count = 0, slots = {} }
    entry.count = entry.count + content.count
    entry.slots[#entry.slots + 1] = slot
    res[content.name] = entry
  end
  return res
end


local function searchStorage(invTable, term)
  local ret = {}
  if not term then
    return ret
  end

  for name, i in pairs(invTable) do
    if string.find(name, term) then
      ret[#ret + 1] = i
    end
  end

  return ret
end

local function moveItems(from, to, itemName, count, itemTable)
  --print(from, to, itemName, count)
  itemTable = itemTable or toLookup(from.list())

  local entry = itemTable[itemName]
  if entry == nil then
    error("Item not found!", 0)
    return 0
  end

  local sentCount = 0
  -- If we fail to send then this'll still iter out but the sentCount will be accurate
  for _, slot in pairs(entry.slots) do
    if sentCount < count then
      local sent = from.pushItems(peripheral.getName(to), slot, count - sentCount)
      sentCount = sentCount + sent
    end
  end
  return sentCount
end


local cacheStaleSecs = 15
local function getCache()
  if _ENV.lectern == nil then
    _ENV.lectern = getLectern()
    _ENV.lecternStale = 0
  end
  if os.clock() >= _ENV.lecternStale then
    print("Updating cache")
    _ENV.lecternCache = toLookup(_ENV.lectern.list())
    _ENV.lecternStale = os.clock() + cacheStaleSecs
  end
  return _ENV.lectern, _ENV.lecternCache
end


return {
  getLectern = getLectern,
  getRoller = getRoller,
  toLookup = toLookup,
  moveItems = moveItems,
  searchStorage = searchStorage,
  getCache = getCache
}
