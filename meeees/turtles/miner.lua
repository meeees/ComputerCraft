local function minerStep()
  local count = 0
  -- gravel might have fallen in front of us
  -- todo - no infinite loop

  while turtle.dig() do
    count = count + 1
  end

  utils.getFuelTo()
  turtle.forward()

  count = count + (turtle.digUp() and 1 or 0)
  count = count + (turtle.digDown() and 1 or 0)
  return count
end

local function minerUp()
  local count = 0
  for _ = 1, 3 do
    turtle.up()
    count = count + (turtle.digUp() and 1 or 0)
  end
  return count
end

local function miner(width, height, depth, settings)
  depth = utils.def(depth, 1)
  -- width is split between left and right
  -- even width will leave one off the right side (width 2 will mine center and left)
  width = utils.def(width, 1)
  height = utils.def(height, 3)

  print("Mining " .. width .. " by " .. height .. " tunnel, " .. depth .. " deep.")

  settings = utils.def(settings, {})
  local torchSlot = utils.def(settings["torch"], 0)
  local torchCheckDist = math.floor(math.max(2, math.min(utils.torchDist, depth / 2)))
  local shulkerSlot = utils.def(settings["shulker"], 0)
  local returnToStart = utils.def(settings["return"], true)

  local heightSteps = math.ceil(height / 3)

  local turns = 0
  local count = 0

  -- move up one block so we're keeping the ground level
  utils.getFuelTo()
  if not turtle.up() then
    count = count + (turtle.digUp() and 1 or 0)
    turtle.up()
  end

  for w = 1, width do
    if w ~= 1 then
      -- face the next wall
      if turns % 2 == 0 then
        turtle.turnRight()
      else
        turtle.turnLeft()
      end

      count = count + minerStep()

      -- finish the turn
      if turns % 2 == 0 then
        turtle.turnRight()
      else
        turtle.turnLeft()
      end
      turns = turns + 1
    end

    -- mine the veritcal slice
    for h = 1, heightSteps do
      -- step up 3 if needed
      if h ~= 1 then
        count = count + minerUp()
        utils.turnAround()
        turns = turns + 1
      end

      local startDepth = (w == 1 and h == 1 and 1) or 2

      for l = startDepth, depth do
        count = count + minerStep()
        if h == 1 and l % torchCheckDist == 0 and torchSlot > 0 and w % torchCheckDist == 1 then
          print("trying to place torch from " .. torchSlot)
          utils.placeFrom(torchSlot, false, true)
        end
      end
    end

    -- return to starting height
    for _ = 1, (heightSteps - 1) * 3 do
      turtle.down()
    end
  end

  if returnToStart then
    -- horizontal align
    if turns % 2 == 0 then
      turtle.turnLeft()
    elseif width > 1 then
      turtle.turnRight()
    end
    for _ = 1, width - 1 do
      utils.getFuelTo()
      turtle.forward()
    end

    -- depth align
    if turns % 2 == 0 then
      turtle.turnLeft()
      for _ = 2, depth do
        utils.getFuelTo()
        turtle.forward()
      end
    elseif width > 1 then
      turtle.turnLeft()
    end
    utils.getFuelTo()
    turtle.forward()
    turtle.down()
    utils.turnAround()
  end

  print("Mined " .. count .. " blocks")
  return count
end

---------- MAIN -------

tArgs = { ... }

if #tArgs ~= 3 and #tArgs ~= 4 then
  print("Usage: " .. arg[0] .. "<width> <height> <depth> (torchSlot)")
  return
end

local width = tonumber(tArgs[1])
local height = tonumber(tArgs[2])
local depth = tonumber(tArgs[3])
local torch = tonumber(utils.def(tArgs[4], "0"))

local mined = miner(width, height, depth, { torch = torch, shulker = 0, returnToStart = true })
print(mined)
