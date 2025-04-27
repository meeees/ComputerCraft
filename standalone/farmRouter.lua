local function findStorage()
  local source, seed, essence

  local list = peripheral.getNames()
  for _, name in pairs(list) do
    if string.find(string.lower(name), "dank") then
      local test = peripheral.wrap(name)
      local checkName = string.lower(test.list()[1].name)
      if string.find(checkName, "essence") then
        essence = test
      elseif string.find(checkName, "seed") then
        seed = test
      end
    elseif string.find(string.lower(name), "chest") then
      local test = peripheral.wrap(name)
      local checkName = string.lower(test.list()[1].name)
      if string.find(checkName, "essence") or string.find(checkName, "seed") then
        source = test
      end
    end
  end
  return source, seed, essence
end

local function doWork(source, seedName, essenceName)
  if not source or not seedName or not essenceName then
    error("Inventory Missing! Check modem connections")
    return
  end
  while true do
    local inv = source.list()
    local seedCnt, essCnt = 0, 0
    for i, item in pairs(inv) do
      if item then
        local name = string.lower(item.name)
        if string.find(name, "essence") then
          essCnt = essCnt + source.pushItems(essenceName, i)
        elseif string.find(name, "seed") then
          seedCnt = seedCnt + source.pushItems(seedName, i)
        end
      end
    end
    print("Moved", essCnt, "Essence,", seedCnt, "Seeds")
    os.sleep(3)
  end
end


local source, seed, essence = findStorage()
local sourceN, seedN, essenceN =
    peripheral.getName(source), peripheral.getName(seed), peripheral.getName(essence)

print("Located storages: Source: ", sourceN, "Seeds:", seedN, "Essence:", essenceN)
doWork(source, seedN, essenceN)
