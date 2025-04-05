local function waitForConfirm(protocol)
  rednet.receive(tostring(protocol))
end

local function sendFile(id, path, destPath, protocol)
  if destPath == nil then
    destPath = path
  end
  local reader = fs.open(path, "r")
  local content = reader.readAll()
  reader.close()
  rednet.send(id, destPath, protocol)
  waitForConfirm(protocol)
  rednet.send(id, content, protocol)
  waitForConfirm(protocol)
  print("Sent " .. destPath .. ", contentLength: " .. string.len(content))
end

local function handleRequest(id, utilsDir, subDir)
  print("Gathering files in " .. subDir .. " & utils for " .. id)

  local protocol = "files:" .. tostring(id)

  local utilFs = fs.list("/meeees/utils")
  local subdirFs = fs.list(subDir)

  local count = #utilFs + #subdirFs
  print("Found " .. count .. " files")
  -- print("Found " .. count " files + 1 startup file")
  -- count = count + 1
  rednet.send(id, count, protocol)
  waitForConfirm(protocol)

  print("Sending files...")
  -- sendFile(id, "/meeees/utils/startup/loadutils.lua", "/startup/loadutils.lua")
  for _, path in pairs(utilFs) do
    local fullPath = utilsDir .. "/" .. path
    sendFile(id, fullPath, fullPath, protocol)
  end
  for _, path in pairs(subdirFs) do
    local fullPath = subDir .. "/" .. path
    sendFile(id, fullPath, fullPath, protocol)
  end
  print("All files sent")
end

----- MAIN RUNNER -----
---
local tArgs = { ... }
if #tArgs ~= 1 then
  print("Usage: " .. arg[0] .. " <rootPath>")
  return
end

-- assuming startup hasn't run, run mbs and utils
if utils == nil then
  shell.run("/startup/00_mbs.lua")
  shell.run("/startup/01_utilpath.lua")
end

local rootPath = tArgs[1]

local modem = peripheral.find("modem")
if modem == nil then
  print("No modem attached!")
  return
end
local modemName = peripheral.getName(modem)

print("Opening file listener for " .. rootPath)
print("Please ensure files have been loaded into the system")

rednet.open(modemName)
rednet.host("files", "host")

while true do
  local id, subDir = rednet.receive("files")
  handleRequest(id, rootPath .. "/utils", rootPath .. "/" .. subDir)
end
