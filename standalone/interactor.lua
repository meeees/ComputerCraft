local sleepTime = tonumber(arg[1])

local slot = turtle.getSelectedSlot()
local core = peripheral.find("weakAutomata")

while turtle.getItemCount(slot) > 0 do
  core.useOnBlock()
  os.sleep(sleepTime or 5)
  core.useOnBlock()
  os.sleep(5)
end
