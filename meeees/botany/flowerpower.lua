local function redstoneOneTick(side)
  redstone.setAnalogOutput(side, 1)
  os.sleep(0.05)
  redstone.setAnalogOutput(side, 0)
end

local function flowerLoop(side)
  local block = peripheral.find("blockReader")

  while true do
    local data = block.getBlockData()

    if data == nil then
      print("No flower to read! Sleeping 5 and restarting loop!")
      os.sleep(5)
    elseif redstone.getAnalogInput('front') > 0 then
      print("Disabled by redstone! Sleeping 5 and restarting loop!")
      os.sleep(5)
    else
      local cooldown = data.cooldown
      local burnTime = data.burnTime
      local mana = data.mana

      if burnTime > 0 then
        local sleepTime = burnTime / 20
        print("Waiting for burn, sleeping " .. sleepTime .. " seconds")
        os.sleep(sleepTime)
      elseif cooldown > 0 then
        local sleepTime = cooldown / 20
        print("Waiting for cooldown, sleeping " .. sleepTime .. " seconds")
        os.sleep(sleepTime)
      elseif mana > 0 then
        print("Waiting for mana to empty, sleeping 5 seconds")
        os.sleep(5)
      else
        print("Pulsing redstone on " .. side)
        redstoneOneTick(side)
        local sleepTime = 5
        print("Sleeping " .. sleepTime .. " seconds")
        os.sleep(sleepTime)
      end
    end
  end
end

if #arg ~= 1 then
  print("Usage: " .. arg[0] .. " <side>")
  return
end

flowerLoop(arg[1])
