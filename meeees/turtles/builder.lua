-- 1xlength stairs going up
local function stairsUp(length, stairBlock)
  stairBlock = utils.def(stairBlock, "stair")
  local slots, total = utils.searchInventory(stairBlock, false)
  local required = length

  if required > total then
    print("Turtle does not have enough " .. stairBlock .. ", please load more")
    return
  end

  local fuelRequired = length * 2
  if not utils.getFuelTo(fuelRequired) then
    print("Turtle does not have enough fuel! please add charcoal")
    return
  end

  local validSlots = {}
  for slot, amt in pairs(slots) do
    if amt ~= nil then
      validSlots[#validSlots + 1] = { slot = slot, amt = amt }
    end
  end

  local curSlot = 1
  turtle.select(validSlots[curSlot].slot)

  local progress = true
  for i = 1, length do
    progress = utils.stepUp()
    progress = utils.stepForward()
    if not progress then
      print("Error! Something blocked the turtle")
      return
    end
    turtle.digDown()
    turtle.digUp()
    if validSlots[curSlot].amt <= 0 then
      curSlot = curSlot + 1
      turtle.select(validSlots[curSlot].slot)
    end
    turtle.placeDown()
    validSlots[curSlot].amt = validSlots[curSlot].amt - 1
  end

  print("Stairs complete!")
end


return {
  stairsUp = stairsUp
}
