hs.notdisturbmode = require("hs.notdisturbmode")

function testNotDisturbMode()
  local isOn =  hs.notdisturbmode.status()

  hs.notdisturbmode.off()
  assertIsEqual(false, hs.notdisturbmode.status())

  hs.notdisturbmode.on()
  assertIsEqual(true, hs.notdisturbmode.status())

  if not isOn then
    hs.notdisturbmode.off()
  end

  return success()
end
