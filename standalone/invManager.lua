inv_pairs = {
  ["inventoryManager_1"] = "minecraft:chest_0",
  ["inventoryManager_4"] = "minecraft:chest_1",
  ["inventoryManager_3"] = "minecraft:chest_2",
  ["inventoryManager_6"] = "minecraft:chest_3",
  ["inventoryManager_5"] = "minecraft:chest_4",
}

-- Seconds between tick procs
local tickTime = 3
local identity = "InvOS"
local command_prefix = "!i "
local storage = "ars_nouveau:storage_lectern_1"
local chat = peripheral.find("chatBox") or error("No chatbox attached!", 0)
-- user -> {item: {state: Or(more, less, exact), count: N}, ...}
local logisticsRequests = {}
local logiMap = {
  ["less"] = -1, --"le",
  ["more"] = 1,  --"ge",
  ["equal"] = 0, --"ee"
}
local logiString = {
  [-1] = "less than",
  [0] = "equal to",
  [1] = "more than",
}
if fs.exists("logi.dat") then
  local f = fs.open("logi.dat", "r")
  logisticsRequests = textutils.unserialize(f.readAll())
  f.close()
end

local function saveLogiReqs()
  local serialized = textutils.serialize(logisticsRequests, { compact = true })
  local f = fs.open("logi.dat", "w")
  f.write(serialized)
  f.close()
end

-- TODO: Better inventory management helpers

local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
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
  for k, v in pairs(tbl) do
    if c == n then
      return k, v
    end
    c = c + 1
  end
  return nil
end

local function keyExists(tbl, key)
  for k, v in pairs(tbl) do
    if k == key then
      return true
    end
  end
  return false
end

local function tableFind(tbl, val)
  for k, v in pairs(tbl) do
    if v == val then
      return k
    end
  end
  return nil
end

local function map(t, func)
  local result = {}
  for i, v in pairs(t) do
    result[i] = func(v)
  end
  return result
end

local function keys(tbl)
  local ret = {}
  for k, _ in pairs(tbl) do
    table.insert(ret, k)
  end
  return ret
end

local function findPeripherals(term)
  local ret = {}
  for _, p in pairs(peripheral.getNames()) do
    if string.find(p, term) then
      table.insert(ret, p)
    end
  end
  return ret
end

local function findInvManagerByUser(username)
  for invM, _chest in pairs(inv_pairs) do
    if peripheral.call(invM, "getOwner") == username then
      return invM
    end
  end
  return nil
end

help = {
  { text = "The following commands are currently available:\n" },
  {
    text = "help",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix .. "help"
    },
  }, { text = " : Displays this message\n" },
  {
    text = "search",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix .. "search "
    },
  }, { text = " : Searches the storage device for the given item\n" },
  { text = "  usage: '" .. command_prefix .. "search <term>'\n" },
  {
    text = "pull",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix .. "pull "
    },
  }, { text = " : Takes a given item from the storage device\n" },
  { text = "  usage: '" .. command_prefix .. "pull <item_name> <count>'\n" },
  {
    text = "list",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix .. "list "
    },
  }, { text = " : Lists your local inventory\n" },
  { text = "  usage: '" .. command_prefix .. "list [search_term]'\n" },
  {
    text = "push",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix .. "push "
    },
  }, { text = " : Moves an item from your inventory to the storage device\n" },
  { text = "  usage: '" .. command_prefix .. "push <item_name> [count=stack_size]'\n" },
  {
    text = "lset",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix .. "lset "
    },
  }, { text = " : Sets a persistent request to have a certain amount of an item in your inventory\n" },
  { text = "  Item name provided must " }, { text = "exactly match", bold = true }, { text = " the item requested!\n" },
  { text = "  usage: '" .. command_prefix .. "lset <item_name> <more | less | equal> <count>'\n" },
  {
    text = "ldel",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix .. "ldel "
    },
  }, { text = " : Removes an existing logistics request\n" },
  { text = "  usage: '" .. command_prefix .. "ldel <item_name>'\n" },
  {
    text = "llist",
    underlined = true,
    color = "red",
    clickEvent = {
      action = "suggest_command",
      value = command_prefix .. "llist "
    },
  }, { text = " : Lists existing logistics requests, optionally filtered on item name\n" },
  { text = "  usage: '" .. command_prefix .. "llist [item filter]'\n" },
}

local function searchStorage(inv_name, term)
  local inventory = peripheral.wrap(inv_name) or error("No inventory attached!", 0)
  local l = inventory.list()
  local ret = {}
  for slot, i in pairs(l) do
    if not term or string.find(i.name, term) then
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
    if not term or string.find(item.name, term) then
      ret[item.slot] = item
    end
  end
  return ret
end

local function getSearchFunc(name)
  if string.find(name, "inventoryManager") then
    return searchPlayerInventory
  end
  return searchStorage
end

local function searchGenericInventory(name, term)
  return getSearchFunc(name)(name, term)
end

-- Takes exact item names
local function multiSearch(name, itemList)
  local ret = {}
  local inv = searchGenericInventory(name, nil)
  for slot, item in pairs(inv) do
    if tableFind(itemList, item.name) then
      if not ret[item.name] then
        ret[item.name] = {}
      end
      ret[item.name][slot] = item
    end
  end
  return ret
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
    table.insert(ret, { name = n, count = cnt })
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

local function collectItem(store, itemName)
  return searchPerfectMatch(collectSearchFmtResults(searchGenericInventory(store, itemName)), itemName)
end

local function pullArbitraryAmount(from, to, itemName, count, preFromSearched)
  --print(from, to, itemName, count)
  local fromSearch = preFromSearched or getSearchFunc(from)(from, itemName)
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
    { text = "[ERR]",                                       color = "red" },
    { text = (" : Failed cmd '%s' because:\n"):format(cmd), color = "white" },
    { text = " " .. reason },
  }
end

local function genPull(name, cnt)
  return {
    text = "Pull",
    underlined = true,
    color = "green",
    clickEvent = {
      action = "suggest_command",
      value = (command_prefix .. "pull %s %d"):format(name, cnt)
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
      value = (command_prefix .. "push %s %d"):format(name, cnt)
    }
  }
end

local function genLogiAdd(name, _cnt)
  return {
    text = "LSet",
    underlined = true,
    color = "aqua",
    clickEvent = {
      action = "suggest_command",
      value = (command_prefix .. "lset %s "):format(name:sub(1, string.find(name, " ")))
    }
  }
end

local function genLogiDel(name, _cnt)
  return {
    text = "LDel",
    underlined = true,
    color = "light_purple",
    clickEvent = {
      action = "suggest_command",
      value = (command_prefix .. "ldel %s"):format(name:sub(1, string.find(name, " ") - 1))
    }
  }
end

-- Minecraft only has a chat history of 100 lines, we take this -3 for your command and top text
chatHistoryMax = 100 - 3
local function searchResFormat(term, itemList, genInteract, msg, separator)
  local m = msg or "The following items matched the term '%s':\n"
  local sep = separator or " - "
  local ret = {
    { text = (m):format(term) },
  }
  local cnt = 0
  local max = 0
  for _, i in pairs(itemList) do
    if cnt < chatHistoryMax then
      if type(genInteract) == "function" then
        table.insert(ret, {
          { text = "[" },
          genInteract(i.name, 1),
          { text = ("] : %s%s%d\n"):format(i.name, sep, i.count) },
        })
      else
        for _, f in pairs(genInteract) do
          table.insert(ret, {
            { text = "[" },
            f(i.name, 1),
            { text = "] " },
          })
        end
        table.insert(ret, {
          { text = (": %s%s%d\n"):format(i.name, sep, i.count) }
        })
      end
      cnt = cnt + 1
    end
    max = max + 1
  end
  if cnt >= chatHistoryMax then
    table.insert(ret, {
      { text = "[WARN]",                                                                                              color = "yellow" },
      { text = (" : There were %d results but we could only display %d due to chat history limits"):format(max, cnt), color = "white" }
    })
  end
  return ret
end


local cmd_case = {
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
    return searchResFormat(cmds[2], collectSearchFmtResults(stored), { genPull, genLogiAdd })
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
      return searchResFormat(cmds[2], matches, { genPull, genLogiAdd },
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
        { text = "[WARN]",                                                                                         color = "yellow" },
        { text = (" : Truncated request from %d to %d due to availability\n"):format(requested_count, item.count), color = "white" }
      })
      requested_count = item.count
    end
    local transferred = pullArbitraryAmount(storage, inv_pairs[invM], item.name, requested_count)
    --local transferred = storage.pushItems(inv_pairs[invM], slot, requested_count)
    if transferred < requested_count then
      table.insert(ret, {
        { text = "[WARN]",                                                                 color = "yellow" },
        { text = (" : Only was able to grab %d items from storage\n"):format(transferred), color = "white" }
      })
      requested_count = transferred
    end
    local sentCount = inv.addItemToPlayer("up", {
      name = item.name,
      count = requested_count
    })
    if sentCount < requested_count then
      table.insert(ret, {
        { text = "[WARN]",                                                                                    color = "yellow" },
        { text = (" : Added %d items to player when %d were requested\n"):format(sentCount, requested_count), color = "white" }
      })
      clearChest(inv_pairs[invM])
    end
    table.insert(ret, 1, {
      { text = "[" }, { text = "+", color = "green" },
      { text = ("] : Successfully pulled %d of '%s'\n"):format(sentCount, item.name) }
    })
    return ret
  end,
  ["list"] = function(invM, cmds)
    local term = cmds[2] or ""
    local matches = searchPlayerInventory(invM, term)
    return searchResFormat(term, collectSearchFmtResults(matches), { genPush, genLogiAdd })
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
      return searchResFormat(cmds[2], matches, { genPush, genLogiAdd },
        "Item name '%s' not specific enough, showing matches:\n"
      )
    end
    local inv = peripheral.wrap(invM) or error("Inventory doesn't exist anymore!", 0)
    local chest = peripheral.wrap(inv_pairs[invM]) or error("Chest doesn't exist anymore!", 0)
    local requested_count = tonumber(cmds[3]) or item.count
    local ret = {}
    local removed = inv.removeItemFromPlayer("up", { name = item.name, count = requested_count })
    if removed < requested_count then
      table.insert(ret, {
        { text = "[WARN]",                                                                   color = "yellow" },
        { text = (" : Removed %d when %d was requested\n"):format(removed, requested_count), color = "white" }
      })
    end
    local cleared = clearChest(peripheral.getName(chest))
    if cleared < removed then
      table.insert(ret, {
        { text = "[WARN]",                                                                                        color = "yellow" },
        { text = (" : Only moved %d from temp chest to storage when %d was intended\n"):format(cleared, removed), color = "white" }
      })
    end
    table.insert(ret, 1, {
      { text = "[" }, { text = "+", color = "green" },
      { text = ("] : Successfully pushed %d of '%s'\n"):format(cleared, item.name) }
    })
    return ret
  end,
  ["lset"] = function(invM, cmds)
    if #cmds < 4 then
      return errorMessage(cmds[1], "Not enough arguments, requires <item name> <more|less|equal> <count>")
    end
    local iCount = tonumber(cmds[4])
    local cState = logiMap[cmds[3]]
    local itemName = cmds[2]
    if not iCount then
      return errorMessage(cmds[1], ("Count argument '%s' was not a valid number!"):format(cmds[4]))
    end
    if not cState then
      return errorMessage(cmds[1], ("State argument '%s' was not either 'more', 'less', or 'equal'!"):format(cmds[3]))
    end
    local username = peripheral.call(invM, "getOwner")
    if not logisticsRequests[username] then
      logisticsRequests[username] = {}
    end
    logisticsRequests[username][itemName] = { count = iCount, state = cState }
    saveLogiReqs()
    return {
      { text = "[" }, { text = "+", color = "green" },
      { text = ("] : Successfully added logistics request for '%s' %s %d\n"):format(itemName, logiString[cState], iCount) }
    }
  end,
  ["ldel"] = function(invM, cmds)
    if #cmds < 2 then
      return errorMessage(cmds[1], "Not enough arguments, requires <item name>")
    end
    local itemName = cmds[2]
    local username = peripheral.call(invM, "getOwner")
    if not logisticsRequests[username] then
      return errorMessage(cmds[1], "You have no existing logistics requests")
    end
    if not keyExists(logisticsRequests[username], itemName) then
      return errorMessage(cmds[1], ("You have no logistics request for '%s'"):format(itemName))
    end
    logisticsRequests[username][itemName] = nil
    saveLogiReqs()
    return {
      { text = "[" }, { text = "+", color = "green" },
      { text = ("] : Successfully deleted logistics request for '%s'\n"):format(itemName) }
    }
  end,
  ["llist"] = function(invM, cmds)
    local searchTerm = cmds[2] or ""
    local username = peripheral.call(invM, "getOwner")
    local ret = {}
    if not logisticsRequests[username] then
      return errorMessage(cmds[1], "You have no existing logistics requests")
    end
    local searchFormattedLogi = {}
    for itemName, logiInfo in pairs(logisticsRequests[username]) do
      table.insert(searchFormattedLogi, {
        name = ("%s %s"):format(itemName, logiString[logiInfo.state]),
        count = logiInfo.count,
      })
    end
    return searchResFormat(searchTerm, searchFormattedLogi, { genLogiAdd, genLogiDel },
      "The following requests match the filter '%s'\n", " ")
  end,
}
local function parseCommand(invM, cmd)
  print(("cmd from user '%s': '%s'"):format(peripheral.call(invM, "getOwner"), cmd))
  local cmds = split(cmd, " ")
  -- Run the case statement
  local f = cmd_case[cmds[1]]
  local ret = nil
  if (f) then
    ret = f(invM, cmds)
  else
    ret = cmd_case["default"](invM, cmds)
  end
  if type(ret) == "string" then
    return { { text = ret } }
  end
  if type(ret) == "table" then
    return ret
  end
  return { { text = "Invalid output from parseCommand" } }
end

local function tryLogisticsRequest(invM, item, logiInfo, storageSearch, invSearch)
  -- Less with only ever send, more will only ever receive. If we can't do the requisite action skip
  if (logiInfo.state < 0 and not invSearch) or (logiInfo.state > 0 and not storageSearch) then
    return true
  end
  -- First determine if we need to remove or add items
  local collected = invSearch and collectResults(invSearch) or nil
  --if not itemInfo then
  --  print("failed to collect item " .. item)
  --end
  local itemCount = collected and collected[item] or 0
  --print(("item count %d"):format(itemCount))
  local requestAmounts = {
    [1] = (itemCount < logiInfo.count) and (logiInfo.count - itemCount) or 0,
    [-1] = (itemCount > logiInfo.count) and (logiInfo.count - itemCount) or 0,
    [0] = logiInfo.count - itemCount,
  }

  local request = requestAmounts[logiInfo.state]
  if not request then
    --print(("request %d invalid"):format(logiInfo.state))
    return false
  end
  --print(("requesting %d of %s"):format(request, item))
  -- Remove items
  if request < 0 then
    local inv = peripheral.wrap(invM) or error("Inventory doesn't exist anymore!", 0)
    local chest = inv_pairs[invM]
    local removed = inv.removeItemFromPlayer("up", { name = item, count = request * -1 })
    clearChest(chest)
  end
  -- Add items
  if request > 0 then
    local inv = peripheral.wrap(invM) or error("Inventory doesn't exist anymore!", 0)
    local chest = inv_pairs[invM]
    -- if storageSearch is nil it means none are in storage, skip this call if so
    local pulled = storageSearch and pullArbitraryAmount(storage, chest, item, request, storageSearch) or 0
    --print(("pulled %d for transfer"):format(pulled))
    if pulled > 0 then
      local added = inv.addItemToPlayer("up", { name = item, count = pulled })
      --print(("added %d to inventory"):format(added))
      clearChest(chest)
    end
  end
  return true
end

local function onTimerTick()
  for user, reqs in pairs(logisticsRequests) do
    local invM = findInvManagerByUser(user)
    if invM then
      local keyVals = keys(reqs)
      if #keyVals > 0 then
        local itemMultisearch = multiSearch(storage, keyVals)
        local invMultisearch = multiSearch(invM, keyVals)
        for item, logiInfo in pairs(reqs) do
          if not tryLogisticsRequest(invM, item, logiInfo, itemMultisearch[item], invMultisearch[item]) then
            logisticsRequests[user][item] = nil
          end
        end
      end
    end
  end
end


local function timerThread()
  local timer_id = os.startTimer(tickTime)
  while true do
    local event, id = os.pullEvent("timer")
    if event == "timer" and id == timer_id then
      local ok, ret = pcall(onTimerTick)
      if not ok then
        print("Timer tick failed! Reason:")
        print(ret)
      end
      timer_id = os.startTimer(tickTime)
    end
  end
end

local function chatThread()
  while true do
    local event, username, message, uuid, isHidden = os.pullEvent("chat")
    if event == "chat" and message:sub(1, #command_prefix) == command_prefix then
      local parsed = false
      for invM, chestM in pairs(inv_pairs) do
        local owner = peripheral.call(invM, "getOwner")
        if username == owner and parsed == false then
          parsed = true
          local command_substr = message:sub(#command_prefix + 1, #message)
          local ok, resp = pcall(parseCommand, invM, command_substr)
          if not ok then
            resp = errorMessage(command_substr, resp)
          end
          chat.sendFormattedMessageToPlayer(textutils.serializeJSON(resp), username, identity, "{}", "&c")
        end
      end
      if parsed == false then
        chat.sendFormattedMessageToPlayer(textutils.serializeJSON({
          { text = ("You aren't a registered user with %s. Please register underneath the main base"):format(identity) },
        }), username, identity, "{}", "&c")
      end
    end
  end
end

parallel.waitForAll(timerThread, chatThread)
