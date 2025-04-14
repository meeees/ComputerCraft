inv_pairs = {
  ["inventoryManager_1"] = "minecraft:chest_0",
  ["inventoryManager_4"] = "minecraft:chest_1",
  ["inventoryManager_3"] = "minecraft:chest_2",
  ["inventoryManager_5"] = "minecraft:chest_3",
  ["inventoryManager_5"] = "minecraft:chest_4",
}

identity = "InvOS"
command_prefix = "!inv "
storage = "ars_nouveau:storage_lectern_1"
chat = peripheral.find("chatBox") or error("No chatbox attached!", 0)

-- TODO: Better inventory management helpers
-- TODO: Collect items of the same type, combine counts, and when pulling handle pulling from multiple slots to fill orders

local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function length(tbl)
  local c = 0
  for _ in pairs(tbl) do c = c + 1 end
  return c
end

local function nth(tbl, n)
  local c = 0
  for k,v in pairs(tbl) do
    if c == n then
      return k,v
    end
    c = c + 1
  end
  return nil
end

help = {
  {text = "The following commands are currently available:\n"},
  {
    text = "help",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix.."help"
    },
  }, {text = " : Displays this message\n"},
  {
    text = "search",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix.."search "
    }, 
  }, {text = " : Searches the storage device for the given item\n"},
  {text = "  usage: '"..command_prefix.."search <term>'\n"},
  {
    text = "pull",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix.."pull "
    }, 
  }, {text = " : Takes a given item from the storage device\n"},
  {text = "  usage: '"..command_prefix.."pull <item_name> <count>'\n"},
  {
    text = "list",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix .. "list "
    }, 
  }, {text = " : Lists your local inventory\n"},
  {text = "  usage: '"..command_prefix.."list [search_term]'\n"},
  {
    text = "push",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix.."push "
    }, 
  }, {text = " : Moves an item from your inventory to the storage device\n"},
  {text = "  usage: '"..command_prefix.."push <item_name> [count=stack_size]'\n"},
}

local function searchStorage(inv_name, term)
  local inventory = peripheral.wrap(inv_name) or error("No inventory attached!", 0)
  local l = inventory.list()
  local ret = {}
  for slot, i in pairs(l) do
    if string.find(i.name, term) then
      ret[slot] = i
    end
  end
  return ret
end

local function clearChest(chestName)
  local chest = peripheral.wrap(chestName)
  local storagePeriph = peripheral.wrap(storage)
  local l = chest.list()
  local r = 0
  for slot, i in pairs(l) do
    r = r + storagePeriph.pullItems(chestName, slot)
  end
  return r
end

local function searchPlayerInventory(invM, term)
  local playerInv = peripheral.wrap(invM)
  local l = playerInv.list()
  -- Returns a sparse array of slot -> item since thats what searchStorage does
  local ret = {}
  for _, item in pairs(l) do
    if string.find(item.name, term) then
      ret[item.slot] = item
    end
  end
  return ret
end

local function getSearchFunc(name)
  if string.find(name, "minecraft:chest") or string.find(name, "ars_nouveau:storage_lectern") then
    return searchStorage
  end
  if string.find(name, "inventoryManager") then
    return searchPlayerInventory
  end
end

local function collectResults(searchRes)
  local ret = {}
  for slot, item in pairs(searchRes) do
    ret[item.name] = (ret[item.name] or 0) + item.count
  end
  return ret
end

-- These slot numbers will absolutely be wrong, do not use them for inv access
local function collectSearchFmtResults(searchRes)
  local ret = {}
  local collected = collectResults(searchRes)
  for n, cnt in pairs(collected) do
    table.insert(ret, {name = n, count = cnt})
  end
  return ret
end

local function searchPerfectMatch(searchRes, term)
  for slot, item in pairs(searchRes) do
    if item.name == term then
      return slot, item
    end
  end
  return nil
end

local function pullArbitraryAmount(from, to, itemName, count)
  print(from, to, itemName, count)
  local fromSearch = getSearchFunc(from)(from, itemName)
  local fromCollected = collectResults(fromSearch)
  local fromPeriph = peripheral.wrap(from)

  local sentCount = 0
  -- If we fail to send then this'll still iter out but the sentCount will be accurate
  for slot, item in pairs(fromSearch) do
    if sentCount < count and item.name == itemName then
      local sent = fromPeriph.pushItems(to, slot, count - sentCount)
      sentCount = sentCount + sent
    end
  end
  return sentCount
end

local function errorMessage(cmd, reason)
  return {
    {text = "[ERR]", color = "red"},
    {text = (" : Failed cmd '%s' because:\n"):format(cmd), color="white"},
    {text = " " .. reason},
  }
end

local function genPull(name, cnt)
  return {
    text = "Pull",
    underlined = true,
    color = "green",
    clickEvent = {
      action = "suggest_command",
      value = (command_prefix.."pull %s %d"):format(name, cnt)
    }
  }
end

local function genPush(name, cnt)
  return {
    text = "Push",
    underlined = true,
    color = "blue",
    clickEvent = {
      action = "suggest_command",
      value = (command_prefix.."push %s %d"):format(name, cnt)
    }
  }
end

-- Minecraft only has a chat history of 100 lines, we take this -3 for your command and top text
chatHistoryMax = 100 - 3
local function searchResFormat(term, itemList, genInteract, msg)
  local m = msg or "The following items matched the term '%s':\n"
  local ret = {
    {text = (m):format(term)},
  }
  local cnt = 0
  local max = 0
  for _, i in pairs(itemList) do
    if cnt < chatHistoryMax then
      table.insert(ret, {
        {text = "["},
        genInteract(i.name, 1),
        {text = ("] : %s - %d\n"):format(i.name, i.count)},
      })
      cnt = cnt + 1
    end
    max = max + 1
  end
  if cnt >= chatHistoryMax then
    table.insert(ret, {
      {text = "[WARN]", color = "yellow"},
      {text = (" : There were %d results but we could only display %d due to chat history limits"):format(max, cnt), color = "white"}
    })
  end
  return ret
end

local function parseCommand(invM, cmd)
  print(("cmd from user '%s': '%s'"):format(peripheral.call(invM, "getOwner"), cmd))
  local cmds = split(cmd, " ")
  local case = {
    ["default"] = function(invM, cmds)
      return ("The command '%s' is not recognized, type 'help'"):format(cmds[1])
    end,
    ["help"] = function(invM, cmds)
      return help
    end,
    ["search"] = function(invM, cmds)
      if #cmds < 2 then
        return errorMessage(cmds[1], "Not enough arguments, requires search term")
      end
      local stored = searchStorage(storage, cmds[2])
      return searchResFormat(cmds[2], collectSearchFmtResults(stored), genPull)
    end,
    ["pull"] = function(invM, cmds)
      if #cmds < 3 then
        return errorMessage(cmds[1], "Not enough arguments, requires item name and count")
      end
      local matches = collectSearchFmtResults(searchStorage(storage, cmds[2]))
      local matchLength = length(matches)
      if matchLength == 0 then
        return errorMessage(cmds[1], ("Item name '%s' doesn't exist in storage"):format(cmds[2]))
      end
      local slot, item = searchPerfectMatch(matches, cmds[2])
      if not slot or not item then
        slot, item = nth(matches, 0)
      end
      if item.name ~= cmds[2] and matchLength ~= 1 then
        return searchResFormat(cmds[2], matches, genPull,
         "Item name '%s' not specific enough, showing matches:\n"
        )
      end
      local inv = peripheral.wrap(invM) or error("Inventory doesn't exist anymore!", 0)
      local chest = peripheral.wrap(inv_pairs[invM]) or error("Chest doesn't exist anymore!", 0)
      local requested_count = tonumber(cmds[3])
      local ret = {}
      if inv.getEmptySpace() == 0 then
        return errorMessage(cmds[1], "Your inventory has no empty slots!")
      end
      if item.count < requested_count then
        table.insert(ret, {
          {text = "[WARN]", color = "yellow" },
          {text = (" : Truncated request from %d to %d due to availability\n"):format(requested_count, item.count), color="white"}
        })
        requested_count = item.count
      end
      local transferred = pullArbitraryAmount(storage, inv_pairs[invM], item.name, requested_count)
      --local transferred = storage.pushItems(inv_pairs[invM], slot, requested_count)
      if transferred < requested_count then
        table.insert(ret, {
          {text = "[WARN]", color = "yellow" },
          {text = (" : Only was able to grab %d items from storage\n"):format(transferred), color="white"}
        })
        requested_count = transferred
      end
      local sentCount = inv.addItemToPlayer("up", {
        name = item.name,
        count = requested_count
      })
      if sentCount < requested_count then 
        table.insert(ret, {
          {text = "[WARN]", color = "yellow" },
          {text = (" : Added %d items to player when %d were requested\n"):format(sentCount, requested_count), color="white"}
        })
        clearChest(inv_pairs[invM])
      end
      table.insert(ret, 1, {
        {text = "["}, {text = "+", color = "green"},
        {text = ("] : Successfully pulled %d of '%s'\n"):format(sentCount, item.name)}
      })
      return ret
    end,
    ["list"] = function(invM, cmds)
      local term = cmds[2] or ""
      local matches = searchPlayerInventory(invM, term)
      return searchResFormat(term, collectSearchFmtResults(matches), genPush)
    end,
    ["push"] = function(invM, cmds)
      if #cmds < 2 then
        return errorMessage(cmds[1], "Not enough arguments, requires item name and optionally count")
      end
      local matches = collectSearchFmtResults(searchPlayerInventory(invM, cmds[2]))
      local matchLength = length(matches)
      if matchLength == 0 then
        return errorMessage(cmds[1], ("Item name '%s' doesn't exist in player inventory"):format(cmds[2]))
      end
      local slot, item = searchPerfectMatch(matches, cmds[2])
      if not slot or not item then
        slot, item = nth(matches, 0)
      end
      if item.name ~= cmds[2] and matchLength ~= 1 then
        return searchResFormat(cmds[2], matches, genPush,
         "Item name '%s' not specific enough, showing matches:\n"
        )
      end
      local inv = peripheral.wrap(invM) or error("Inventory doesn't exist anymore!", 0)
      local chest = peripheral.wrap(inv_pairs[invM]) or error("Chest doesn't exist anymore!", 0)
      local requested_count = tonumber(cmds[3]) or item.count
      local ret = {}
      local removed = inv.removeItemFromPlayer("up", {name=item.name, count=requested_count})
      if removed < requested_count then
        table.insert(ret, {
          {text = "[WARN]", color = "yellow" },
          {text = (" : Removed %d when %d was requested\n"):format(removed, requested_count), color="white"}
        })
      end
      local cleared = clearChest(peripheral.getName(chest))
      if cleared < removed then
        table.insert(ret, {
          {text = "[WARN]", color = "yellow" },
          {text = (" : Only moved %d from temp chest to storage when %d was intended\n"):format(cleared, removed), color="white"}
        })
      end
      table.insert(ret, 1, {
        {text = "["}, {text = "+", color = "green"},
        {text = ("] : Successfully pushed %d of '%s'\n"):format(cleared, item.name)}
      })
      return ret
    end,
  }
  -- Run the case statement
  local f = case[cmds[1]]
  local ret = nil
  if (f) then
    ret = f(invM, cmds)
  else
    ret = case["default"](invM, cmds)
  end
  if type(ret) == "string" then
    return {{text = ret}}
  end
  if type(ret) == "table" then
    return ret
  end
  return {{text = "Invalid output from parseCommand"}}
end

while true do
  local event, username, message, uuid, isHidden = os.pullEvent("chat")
  if message:sub(1, #command_prefix) == command_prefix then
    local parsed = false
    for invM, chestM in pairs(inv_pairs) do
      local owner = peripheral.call(invM, "getOwner")
      if username == owner and parsed == false then
        parsed = true
        local resp = parseCommand(invM, message:sub(#command_prefix + 1, #message))
        chat.sendFormattedMessageToPlayer(textutils.serializeJSON(resp), username, identity, "{}", "&c")
      end
    end
    if parsed == false then
      chat.sendFormattedMessageToPlayer(textutils.serializeJSON({
        {text = ("You aren't a registered user with %s. Please register underneath the main base"):format(identity)},
      }), username, identity, "{}", "&c")
    end
  end
end
