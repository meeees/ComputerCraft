local steps = tonumber(arg[1])
local fuelSlot = tonumber(utils.def(arg[2], 1))

for _ = 1, steps do
  utils.refuelCheck(fuelSlot)
  turtle.forward()
end
