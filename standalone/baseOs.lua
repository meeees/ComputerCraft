local identity = "BaseOS"
local identWrapper = "{}"
local basePrefix = "!t"
local tickTime = 5

-- string utils
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
-- end string utils

-- File Utils
local function loadFile(fname)
  if fs.exists(fname) then
    local f = fs.open(fname, "r")
    dat = textutils.unserialize(f.readAll())
    f.close()
    return dat
  end
  return nil
end

local function writeFile(fname, dat)
  local serialized = textutils.serialize(dat, { compact = true })
  local f = fs.open(fname, "w")
  f.write(serialized)
  f.close()
end
-- End File Utils

-- chat utils
local chat = peripheral.find("chatBox") or error("No chatbox attached!", 0)
local function errorMessage(cmd, reason)
  return {
    { text = "[ERR]",                                       color = "red" },
    { text = (" : Failed '%s' because:\n"):format(cmd), color = "white" },
    { text = " " .. reason },
  }
end

local function genChatList(data, genEntry, prefix, extraArg)
  local ret = {}
  if prefix then
    table.insert(ret, {text = prefix .. "\n"})
  end
  for k,v in pairs(data) do
    table.insert(ret, genEntry(v, k, extraArg))
    table.insert(ret, {text = "\n"})
  end
  return ret
end

local function suggestCommand(textPrompt, textColor, cmd)
  return {
    text = textPrompt, 
    underlined = true, 
    color = textColor or "red",
    clickEvent = {
      action = "suggest_command",
      value = cmd,
    }
  }
end

local function statusMessage(message)
  return {
      { text = "[" }, { text = "+", color = "green" },
      { text = ("] : %s\n"):format(message) }
  }
end

local function sendPrivMsg(message, username)
  chat.sendFormattedMessageToPlayer(textutils.serializeJSON(message), username, identity, identWrapper, "&c")
end
-- end chat utils

-- InvManager
-- Used to abstract inventory usage
local invLookup = {}
local InvManager = {}
InvManager.__index = InvManager
function InvManager:new(name)
  local lookup = invLookup[name]
  if lookup then
    return lookup
  end
  if not peripheral.hasType(name, "inventory") then
    print("ERR: Failed to create inventory with " .. name)
    return nil
  end
  o = {}
  setmetatable(o, self)
  o.name = name
  o.inv = {}
  o.periph = peripheral.wrap(name)
  o.size = o.periph.size()
  invLookup[name] = o
  return o
end

function InvManager:getInv(pullNew)
  if pullNew then
    self.inv = self.periph.list()
  end
  return self.inv
end

function InvManager:search(filter)
  local ret = {}
  local inv = self.inv
  local tagFilter = filter.tag
  local nameFilter = filter.name
  local count = 0
  for i=1,self.size do
    local item = inv[i]
    if item then
      -- if tagFilter then
      --   if not item.tags then
      --     item = self.periph.getItemDetail(i)
      --     inv[i] = item
      --   end
      --   if item.tags[tagFilter] then
      --     ret[i] = item
      --     count = count + item.count
      --   end
      -- end
      if nameFilter then
        if item.name == nameFilter then
          ret[i] = item
          count = count + item.count
        end
      end
    end
  end
  return ret, count
end

function InvManager:pushItem(dest, filter, count)
  print(("Trying to push %d of item %s to %s"):format(count, textutils.serialize(filter), dest))
  local res = self:search(filter)
  local pushed = 0
  for slot, item in pairs(res) do
    print(textutils.serialize(item))
    local itemCount = item.count
    local prevPushed = pushed
    while pushed < count and (pushed - prevPushed) < itemCount do
      pushed = pushed + self.periph.pushItems(dest, slot, count)
    end
  end
  return pushed
end
-- end InvManager

-- TODO: Crafting manager

-- Logistics
local LogiSystem = {}
LogiSystem.__index = LogiSystem
function LogiSystem:new(fname)
  o = {}
  if fname then
    o = loadFile(fname)
  end
  o = o or {}
  setmetatable(o, self)
  -- Only passive providers, active providers will for sure fill up the storage
  -- Items will never be transferred to providers
  o.providers = o.providers or {}
  o.providersUpdated = false
  -- Requesters only pull items in
  o.requesters = o.requesters or {}
  -- Storers store items and may provide to requesters
  o.storers = o.storers or {}
  o.storersUpdated = false
  return o
end

function LogiSystem:save()
  writeFile("logistics.dat", self)
end

function LogiSystem:pullItem(toInv, item, count)
  print(("Attempting to pull %d %s to %s"):format(count, textutils.serialize(item), toInv))
  local providers = self.providers
  local pulled = 0
  local providersUpdated = self.providersUpdated
  print("Checking providers")
  for i=1,#providers do
    local name = providers[i]
    local inv = InvManager:new(name)
    if not providersUpdated then
      inv:getInv(true)
    end
    if pulled < count then
      pulled = pulled + inv:pushItem(toInv, item, count)
    end
  end
  self.providersUpdated = true
  if pulled < count then 
    local storersUpdated = self.storersUpdated
    local storers = self.storers
    print("checking storers ", #storers)
    for i=1,#storers do
      local name = storers[i]
      print("checking storer " .. name)
      local inv = InvManager:new(name)
      if not storersUpdated then
        print("pulling inv")
        inv:getInv(true)
      end
      if pulled < count then
        pulled = pulled + inv:pushItem(toInv, item, count)
      end
    end
    self.storersUpdated = true
  end
  return pulled
end

function LogiSystem:tickRequests()
  for name,requests in pairs(self.requesters) do
    local inv = InvManager:new(name)
    -- Update the inventory
    inv:getInv(true)
    for i=1,#requests do
      local req = requests[i]
      local results, count = inv:search(req)
      -- print(("Found %d for %s"):format(count, textutils.serialize(req)))
      if count < req.count then
        self:pullItem(name, req, req.count - count)
      end
    end
  end
  -- After the requests reset these so we update again later
  self.providersUpdated = false
  self.storersUpdated = false
end

function LogiSystem:addRequest(inv, itemReq)
  local requests = self.requesters[inv]
  if not requests then
    self.requesters[inv] = {itemReq}
    self:save()
    return
  end
  for i=1,#requests do
    local req = requests[i]
    if (itemReq.name and (req.name == itemReq.name)) or (itemReq.tag and (req.tag == itemReq.tag)) then
      req.count = itemReq.count
      self:save()
      return
    end
  end
  table.insert(requests, itemReq)
  self:save()
end

function LogiSystem:removeRequest(inv, itemReq)
  local requests = self.requesters[inv]
  if requests then
    for i=1,#requests do
      local req = requests[i]
      if req.item == itemReq.item or req.tag == itemReq then
        requests[i] = nil
        self:save()
      end
    end
  end
end

function LogiSystem:addStorer(inv)
  local storers = self.storers
  for i=1,#storers do
    if storers[i] == inv then
      return
    end
  end
  table.insert(self.storers, inv)
  self:save()
end

function LogiSystem:addProvider(inv)
  local providers = self.providers
  for i=1,#providers do
    if providers[i] == inv then
      return
    end
  end
  table.insert(self.providers, inv)
  self:save()
end

function LogiSystem:removeStorer(inv)
  local storers = self.storers
  for i=1,#storers do 
    local invName = storers[i]
    if invName == inv then
      table.remove(self.storers, i)
      self:save()
      return
    end
  end
end

function LogiSystem:removeProvider(inv)
  local providers = self.providers
  for i=1,#providers do 
    local invName = providers[i]
    if invName == inv then
      table.remove(self.providers, i)
      self:save()
      return
    end
  end
end

local globalLogi = LogiSystem:new("logistics.dat")
-- end Logistics



-- CommandHandler
local CommandHandler = {}
CommandHandler.__index = CommandHandler
-- Takes in:
-- - prefix : what the command must be prefixed with to run
-- - data : passed to handlers
-- - helpPrefix : what prints in the help menu
function CommandHandler:new(prefix, data, helpPrefix, cmdColor, superPrefix)
  o = {}
  setmetatable(o, self)
  o.prefix = prefix
  o.commands = {}
  o.data = data or {}
  o.helpPrefix = helpPrefix or ("The following commands are available for %s:\n"):format(prefix)
  o.cmdColor = cmdColor or "red"
  o.superPrefix = superPrefix
  return o
end

-- Takes in:
-- - cmd : Name of the command
-- - func : handler function takes args (cmds, data)
-- - suggestedArgs : prefilled for suggestions in helpText
-- - helpText : what to print in the help menu
-- - usage : usage args text
-- - arg : passed to the command handler first if present
function CommandHandler:addCommand(cmd, func, suggestedArgs, helpText, usage, arg)
  self.commands[cmd] = {func, suggestedArgs, helpText, usage, arg}
end

-- Takes in a single cmd name
function CommandHandler:removeCommand(cmd)
  self.commands[cmd] = nil
end

-- Takes in a list of strings
-- Returns a value if the command was handled
function CommandHandler:runCommand(cmds)
  -- print("running cmd handler for " .. self.prefix)
  -- print(textutils.serialize(cmds))
  if cmds[1] == self.prefix then
    for k,v in pairs(self.commands) do
      if k == cmds[2] then
        -- print("matched on " .. k)
        local passedArgs = {unpack(cmds, 2, #cmds)}
        if v[5] then
          return v[1](v[5], passedArgs, self.data)
        else
          return v[1](passedArgs, self.data)
        end
      end
    end
  end
  return nil
end

function CommandHandler:getPrefix()
  if self.superPrefix then
    return self.superPrefix .. " " .. self.prefix
  end
  return self.prefix
end

function CommandHandler:suggestCommand(name, args)
  return ("%s %s %s"):format(self:getPrefix(), name, args or "")
end

function CommandHandler:printHelp(expand)
  local ret = {}
  local helpPrefix = self.helpPrefix
  local expandChildren = expand or false
  local helpType = type(helpPrefix)
  if helpType == "string" then
    table.insert(ret, {text = helpPrefix})
  else
    if helpType == "table" then
      table.insert(ret, helpPrefix)
    end
  end
  local cmdPrefix = self:getPrefix()
  if expandChildren then
    for k,v in pairs(self.commands) do
      local helpDat = v[3]
      table.insert(ret, suggestCommand(k, self.cmdColor, ("%s %s %s"):format(cmdPrefix, k, v[2] or "")))
      table.insert(ret, {text = " : "})
      local typeHelp = type(helpDat)
      if typeHelp == "string" then
        table.insert(ret, {text = helpDat})
      else
        if typeHelp == "table" then
          table.insert(ret, helpDat)
        else
          if typeHelp == "function" then
            table.insert(ret, helpDat())
          end
        end
      end
      if v[4] then 
        table.insert(ret, {text = ("\nusage: %s %s"):format(cmdPrefix, v[4])})
      end
      table.insert(ret, {text = "\n"})
    end
  end
  return ret
end

local function runHelp(cmdHandler, expand)
  return cmdHandler:printHelp(expand or true)
end
local function runCommands(cmdHandler, cmds)
  return cmdHandler:runCommand(cmds)
end
-- End CommandHandler


-- Set up command handlers
local mainCmdHandler = CommandHandler:new(basePrefix, nil, "The following commands are available:\n")
local mngCmdHandler = CommandHandler:new("mng", nil, "Management subsystem has the following commands available:\n", "red", mainCmdHandler:getPrefix())
local logiCmdHandler = CommandHandler:new("logi", nil, "Logistics subsystem has the following commands available:\n", "blue", mainCmdHandler:getPrefix())
mngCmdHandler:addCommand("help", runHelp, nil, "Prints this menu", nil, mngCmdHandler)

mainCmdHandler:addCommand("help", runHelp, nil, "Prints this menu", nil, mainCmdHandler)
mainCmdHandler:addCommand(mngCmdHandler.prefix, runCommands, "help", "Management subsystem commands", nil, mngCmdHandler)
mainCmdHandler:addCommand(logiCmdHandler.prefix, runCommands, "help", "Logistics subsystem commands", nil, logiCmdHandler)

local function testCmd(cmds)
  return {text = "test\n"}
end
mngCmdHandler:addCommand("test", testCmd, nil, "Test command")

local function listPeripherals()
  return genChatList(peripheral.getNames(), function(p) 
    return {text = ("%s types: %s"):format(p, textutils.serializeJSON({peripheral.getType(p)}))}
  end)
end
mngCmdHandler:addCommand("plist", listPeripherals, nil, "List all peripherals on the network")

-- Logi commands
local function addStorerCmd(cmds)
  local storer = cmds[2]
  if not storer then
    return errorMessage("addStorer", "No inventory name provided!")
  end
  if peripheral.hasType(storer, "inventory") then
    globalLogi:addStorer(storer)
    return statusMessage(("Sucessfully added %s as a storer!"):format(storer))
  else
    return errorMessage("addStorer", ("%s is not a valid inventory!"):format(storer))
  end
end

local function addProviderCmd(cmds)
  local provider = cmds[2]
  if not provider then
    return errorMessage("addProvider", "No inventory name provided!")
  end
  if peripheral.hasType(provider, "inventory") then
    globalLogi:addProvider(provider)
    return statusMessage(("Sucessfully added %s as a provider!"):format(provider))
  else
    return errorMessage("addProvider", ("%s is not a valid inventory!"):format(provider))
  end
end

local function removeStorerCmd(cmds)
  local storer = cmds[2]
  if not storer then
    return errorMessage("removeStorer", "No inventory name provided!")
  end
  if peripheral.hasType(storer, "inventory") then
    globalLogi:removeStorer(storer)
    return statusMessage(("Sucessfully removed %s as a storer!"):format(storer))
  else
    return errorMessage("removeStorer", ("%s is not a valid inventory!"):format(storer))
  end
end

local function removeProviderCmd(cmds)
  local provider = cmds[2]
  if not provider then
    return errorMessage("removeProvider", "No inventory name provided!")
  end
  if peripheral.hasType(provider, "inventory") then
    globalLogi:removeProvider(provider)
    return statusMessage(("Sucessfully removed %s as a provider!"):format(provider))
  else
    return errorMessage("removeProvider", ("%s is not a valid inventory!"):format(provider))
  end
end

local function addRequestCmd(reqType, cmds)
  local invName = cmds[2]
  local reqData = cmds[3]
  local cnt = tonumber(cmds[4])
  if not invName or not reqData or not cnt then
    return errorMessage("addRequest", "One or more arguments not provided!")
  end
  if not peripheral.hasType(invName, "inventory") then
    return errorMessage("addRequest", ("%s is not a valid inventory"):format(invName))
  end
  local req = {count = cnt}
  req[reqType] = reqData
  globalLogi:addRequest(invName, req)
  return statusMessage(("Successfully added request to %s for %d of %s"):format(invName, cnt, reqData))
end

local function removeRequestCmd(cmds)
  local invName = cmds[2]
  local request = cmds[3]
  if not invName or not request then
    return errorMessage("removeRequest", "One or more arguments not provided!")
  end
  if not peripheral.hasType(invName, "inventory") then
    return errorMessage("removeRequest", ("%s is not a valid inventory"):format(invName))
  end
  globalLogi:removeRequest(invName, request)
  return statusMessage(("Successfully removed request to %s for %s"):format(invName, request))
end

local function genLogiStorageEntry(name)
  return {
    {text = "["},
    suggestCommand("Remove", "red", logiCmdHandler:suggestCommand("removeStorage", name)),
    {text = "] : " .. name},
  }
end

local function genLogiProviderEntry(name)
  return {
    {text = "["},
    suggestCommand("Remove", "red", logiCmdHandler:suggestCommand("removeProvider", name)),
    {text = "] : " .. name},
  }
end

local function listStorageCmd(cmds)
  return genChatList(globalLogi.storers, genLogiStorageEntry, "Storage inventories registered:")
end
local function listProvidersCmd(cmds)
  return genChatList(globalLogi.providers, genLogiProviderEntry, "Provider inventories registered:")
end

local function genRequestEntry(req, index, inv)
  local nameOrTag = req.name or req.tag
  local suggestArgs = ("%s %s %d"):format(inv, nameOrTag, req.count)
  return {
    {text = "["},
    req.name and suggestCommand("Edit", "green", logiCmdHandler:suggestCommand("addNameRequest", suggestArgs)) or suggestCommand("Edit", "green", logiCmdHandler:suggestCommand("addTagRequest", suggestArgs)),
    {text = "] ["},
    suggestCommand("Remove", "red", logiCmdHandler:suggestCommand("removeRequest", ("%s %s"):format(inv, nameOrTag))),
    {text = ("] : %s %d"):format(nameOrTag, req.count) }
  }
end
local function genLogiRequestEntry(req, inv)
  return genChatList(req, genRequestEntry, ("Requests for inventory %s:"):format(inv), inv)
end
local function listRequestsCmd(cmds)
  return genChatList(globalLogi.requesters, genLogiRequestEntry, "Requests currently in the system:")
end

logiCmdHandler:addCommand("help", runHelp, nil, "Prints this menu", nil, logiCmdHandler)
logiCmdHandler:addCommand("addStorage", addStorerCmd, nil, "Adds an inventory as storage", "<inventory name>")
logiCmdHandler:addCommand("addProvider", addProviderCmd, nil, "Adds an inventory as a provider", "<inventory name>")
logiCmdHandler:addCommand("removeStorage", removeStorerCmd, nil, "Removes an inventory as storage", "<inventory name>")
logiCmdHandler:addCommand("removeProvider", removeProviderCmd, nil, "Removes an inventory as a provider", "<inventory name>")
logiCmdHandler:addCommand("addNameRequest", addRequestCmd, nil, "Adds an item name request to an inventory", "<inventory name> <item name> <min count>", "name")
-- logiCmdHandler:addCommand("addTagRequest", addRequestCmd, nil, "Adds an item tag request to an inventory", "<inventory name> <item tag> <min count>", "tag")
logiCmdHandler:addCommand("removeRequest", removeRequestCmd, nil, "Removes a request from an inventory", "<inventory name> <item tag or name>")
logiCmdHandler:addCommand("listStorage", listStorageCmd, nil, "Lists all storage inventories")
logiCmdHandler:addCommand("listProviders", listProvidersCmd, nil, "Lists all provider inventories")
logiCmdHandler:addCommand("listRequests", listRequestsCmd, nil, "Lists all requests in the system")
-- end Logi commands


local function chatThread()
  local command_prefix = mainCmdHandler:getPrefix()
  print(command_prefix)
  while true do
    local event, username, message, uuid, isHidden = os.pullEvent("chat")
    if event == "chat" and message:sub(1, #command_prefix) == command_prefix then
      print(username, message)
      local cmds = split(message, " ")
      local ok, ret = pcall(runCommands, mainCmdHandler, cmds)
      if not ok then
        local resp = errorMessage(cmds[1], ret)
        sendPrivMsg(resp, username)
      else
        if ret then
          sendPrivMsg(ret, username)
        end
      end
    end
  end
end

local function onTimerTick()
  globalLogi:tickRequests()
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

parallel.waitForAll(timerThread, chatThread)