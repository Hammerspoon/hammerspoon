hs.donotdisturb = require("hs.donotdisturb")

function testDoNotDisturb()
  local isOn = hs.donotdisturb.status()

  hs.donotdisturb.off()
  assertIsEqual(false, hs.donotdisturb.status())

  hs.donotdisturb.on()
  assertIsEqual(true, hs.donotdisturb.status())

  if not isOn then
    hs.donotdisturb.off()
  end

  return success()
end
