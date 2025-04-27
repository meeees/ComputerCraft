local bottom = peripheral.wrap("bottom")
local min, max = ...

if not min or not max then
  print("need args <min percentage> <max percentage>")
  print("burn will start at max percentage and go until min percentage")
  exit()
end

min = tonumber(min)
max = tonumber(max)

if max > 100 or max < 1 then
  print("max needs to be between 1 and 100")
  exit()
end

if min < 0 or min > 99 then
  print("min needs to be between 0 and 100")
  exit()
end

min = min / 100
max = max / 100

local function burnCheck()
  local fillPercent = bottom.getFilledPercentage()
  if fillPercent >= max then
    redstone.setOutput("back", true)
    while bottom.getFilledPercentage() > min do
      os.sleep(1)
    end
    redstone.setOutput("back", false)
  end
end

while true do
  burnCheck()
  os.sleep(10)
end