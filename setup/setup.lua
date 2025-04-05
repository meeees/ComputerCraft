local function sendFileAck(hostId, protocol)
  rednet.send(hostId, "", protocol)
end

local function pullFiles(subDir)
  local modem = peripheral.find("modem")
  local modemName = peripheral.getName(modem)
  rednet.open(modemName)
  local host = rednet.lookup("files", "host")
  if host == nil then
    print("Error: Could not load files, file host not found")
    return false
  end

  -- host will send back number of files, followed by pairs of 2 packets: (filename, filecontent)
  -- files will be for our subDir and any utils
  rednet.send(host, subDir, "files")
  print("Requesting files: " .. subDir)
  -- now that the host knows who we are, switch to unique protocol
  local myProtocol = "files:" .. tostring(os.getComputerID())


  local _, count = rednet.receive(myProtocol)
  print("expecting " .. count .. " files")

  sendFileAck(host, myProtocol)
  for _ = 1, tonumber(count) do
    local _, path = rednet.receive(myProtocol)
    sendFileAck(host, myProtocol)
    local _, content = rednet.receive(myProtocol)
    sendFileAck(host, myProtocol)
    print("Copying " .. path)
    local file = fs.open(path, "w")
    file.write(content)
    file.close()
  end
  print("Copied " .. count .. " files")
  return true
end

local function confirmCheck(msg)
  print(msg .. " (y/n)")
  return string.lower(io.read()) == "y"
end

local function writeUtilLoader()
  local pathScript = fs.open("/startup/01_utilpath.lua", "w")
  pathScript.write("shell.setPath(shell.path() .. \":/meeees/utils\")\n")
  pathScript.write("_G.utils = dofile(\"/meeees/utils/utils.lua\")\n")
end


---------- MAIN ------------


local tArgs = { ... }
local type = "basic"

local supported = { basic = 1, miner = 1, minerhost = 1, filehost = 1, mbs = 1 }
if #tArgs == 1 then
  type = tArgs[1]
else
  print("Defaulting to basic setup!")
end

type = string.lower(type)

if supported[type] == nil then
  if type == "code" then
    print("Code setup, only requesting files from host")
    local codePath = settings.get("code-subDir")
    if codePath ~= nil then
      if not pullFiles(codePath) then
        print("Setup failed!")
      end
    else
      print("No code path set to pull from!")
    end
    return
  elseif type == "reset" then
    if confirmCheck("This will reset the computer, are you sure?") then
      shell.execute("rm", "/meeees")
      shell.execute("rm", "/startup")
      shell.execute("rm", "mbs.lua")
      if confirmCheck("meeees and startup folders removed. Restart now?") then
        shell.execute("reboot")
      end
    else
      print("Reset aborted.")
    end
    return
  else
    print("Setup for " .. type .. " is unsupported!")
    print("Supported types: [" ..
      (function()
        local res = ""; for key, _ in pairs(supported) do res = res .. key .. ", " end
        return res
      end)()
      .. "]"
    )
    return
  end
end

local needsReboot = false

print("Running " .. type .. "setup, pulling MBS if needed")
shell.execute("cd", "/")
if not fs.exists("/mbs.lua") or type == "mbs" then
  shell.execute("wget", "https://raw.githubusercontent.com/SquidDev-CC/mbs/master/mbs.lua", "mbs.lua")
  shell.run("mbs", "install")
  needsReboot = true
end

settings.set("setup-type", type)
local codePath
if type == "miner" then
  codePath = "turtles"
end
if type == "minerhost" then
  codePath = "minerHost"
end

if codePath ~= nil then
  settings.set("code-subDir", codePath)
else
  settings.clear("code-subDir")
end
settings.save()

if codePath ~= nil then
  if pullFiles(codePath) then
    if not fs.exists("/startup/01_utilpath.lua") then
      writeUtilLoader()
      needsReboot = true
    end
  else
    print("Setup failed!")
    return
  end
end

if type == "filehost" then
  writeUtilLoader()
  local fileScript = fs.open("startup/02_filestarter.lua", "w")
  fileScript.write("multishell.launch(_ENV, \"/filehost.lua\", \"/meeees\")\n")
  fileScript.write("print(\"if filehost doesn't run, it must be manually installed on the machine\")\n")
  fileScript.close()
end

print(type .. " setup complete!")
if needsReboot then
  if confirmCheck("Reboot required, Reboot now?") then
    print("Rebooting...")
    shell.execute("reboot")
  end
end
