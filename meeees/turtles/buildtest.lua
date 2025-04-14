local function buildRect(x, y)
  for i = 1, x do
    local stop
    if i == 1 then
      stop = y
    else
      stop = y - 1
    end
    for j = 1, stop do
      turtle.dig()
      turtle.digUp()
      turtle.forward()
      -- turtle.placeDown()
    end
    if i % 2 == 1 then
      turtle.turnRight()
    else
      turtle.turnLeft()
    end
    if i ~= x then
      turtle.dig()
      turtle.digUp()
      turtle.forward()
      -- turtle.placeDown()
      if i % 2 == 1 then
        turtle.turnRight()
      else
        turtle.turnLeft()
      end
    end
  end
end

buildRect(10, 10)
