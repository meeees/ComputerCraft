local core = peripheral.find("weakAutomata")

while true do
  -- print("Running Loop")
  local _, info = turtle.inspect()
  -- print(info)
  if info ~= nil and info.state ~= nil and info.state.fluid == 'empty' then
    print("filling block")
    core.useOnBlock()
    turtle.placeDown()
  end
  os.sleep(5)
end
