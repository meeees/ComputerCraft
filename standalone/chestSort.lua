local tickTime = 10
local transferCheck = 1
local fromChest = "sophisticatedstorage:chest_2"
local stackableChest = "ars_nouveau:storage_lectern_1"
local singleChest = "sophisticatedstorage:chest_1"

local function sortItems(sourceName, stackableDest, singleDest)
  local inv = peripheral.wrap(sourceName)
  local invSize = inv.size()
  local itemsPushed = false
  for i = 1, invSize do
    local limit = inv.getItemLimit(i)
    local detail = inv.getItemDetail(i)
    if detail then
      if limit ~= detail.maxCount and detail.maxCount ~= 1 then
        print(("%s is not fully stackable %d / %d"):format(detail.name, detail.maxCount, limit))
      end
      if detail.maxCount == 1 then
        inv.pushItems(singleDest, i, detail.count)
      else
        inv.pushItems(stackableDest, i, detail.count)
      end
      itemsPushed = true
    end
  end
  return itemsPushed
end

local function timerThread()
  local curTick = tickTime
  local timer_id = os.startTimer(curTick)
  while true do
    local event, id = os.pullEvent("timer")
    if event == "timer" and id == timer_id then
      local ok, ret = pcall(sortItems, fromChest, stackableChest, singleChest)
      if not ok then
        print("Timer tick failed! Reason:")
        print(ret)
      else
        if ret then
          curTick = transferCheck
        else
          curTick = tickTime
        end
      end
      timer_id = os.startTimer(curTick)
    end
  end
end

timerThread()