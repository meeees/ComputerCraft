local tick = 0.05

local function redstoneTick(side, tickCount)
  tickCount = tickCount or 1
  redstone.setOutput(side, true)
  os.sleep(tick * tickCount)
  redstone.setOutput(side, false)
  os.sleep(tick)
end

local function redCheck(side)
  return redstone.getInput(side)
end

local placeBlocks = "back"
local pushAcross = "top"
local pushDown = "right"
local chestCheck = "left"
local placerCheck = "front"
local endCheck = "bottom"

-- doing 2 ticks for everything to maybe cut lag in half?

local function runOneSlice()
  if not redCheck(placerCheck) then
    print("Warning: Detected no blocks in first placer!")
  end
  for i = 1, 12 do
    redstoneTick(placeBlocks, 2)
    redstoneTick(pushAcross, 2)
  end
  -- wait a couple ticks
  os.sleep(tick * 4)
  redstoneTick(pushDown, 4)
end


-- after 13 cycles, we won't be able to push any more down
-- todo - connect to modems to access more redstone?
local function runMaxSlice()
  local chestEmpty = false
  local chest = peripheral.wrap(chestCheck)

  if chest == nil then
    print("Warning: No chest detected! Will only run until first placer is empty!")
    chestEmpty = true
  end
  for i = 1, 13 do
    chestEmpty = #(chest.list()) == 0
    runOneSlice()

    -- wait 5 seconds for ores to propogate through pipes
    os.sleep(5)

    if chestEmpty and i < 13 and not redCheck(placerCheck) then
      print("Detected no more blocks, ending early!")
      return
    end
  end
end

if arg[1] == 'full' then
  runMaxSlice()
elseif arg[1] == 'one' then
  runOneSlice()
else
  if arg[1] ~= 'help' then
    print("Unknown arg!")
  end
  print("Usage: " .. arg[0] .. "<help|full|one>")
end
