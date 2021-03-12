
function testAvailablePortNames()
  local availablePortNames = hs.serial.availablePortNames()
  assertTrue(type(availablePortNames) == "table")
  return success()
end

function testAvailablePortPaths()
  local availablePortPaths = hs.serial.availablePortPaths()
  assertTrue(type(availablePortPaths) == "table")
  return success()
end

function testNewFromName()
  local obj = hs.serial.newFromName("Bluetooth-Incoming-Port")
  assertIsUserdataOfType("hs.serial", obj)
  assertTrue(#tostring(obj) > 0)
  return success()
end

function testNewFromPath()
  local obj = hs.serial.newFromPath("/dev/cu.Bluetooth-Incoming-Port")
  assertIsUserdataOfType("hs.serial", obj)
  assertTrue(#tostring(obj) > 0)
  return success()
end

function testOpenAndClose()
  local obj = hs.serial.newFromPath("/dev/cu.Bluetooth-Incoming-Port")
  assertIsUserdataOfType("hs.serial", obj)
  assertTrue(#tostring(obj) > 0)

  obj:open()

  hs.timer.usleep(1000000)
  hs.timer.usleep(1000000)

  assertTrue(obj:isOpen())

  hs.timer.usleep(1000000)
  hs.timer.usleep(1000000)

  obj:close()

  hs.timer.usleep(1000000)
  hs.timer.usleep(1000000)

  assertTrue(obj:isOpen() == false)

  return success()
end

function testAttributes()
  local obj = hs.serial.newFromPath("/dev/cu.Bluetooth-Incoming-Port")
  assertIsUserdataOfType("hs.serial", obj)
  assertTrue(#tostring(obj) > 0)

  obj:open()

  hs.timer.usleep(1000000)
  hs.timer.usleep(1000000)

  assertTrue(obj:isOpen())

  hs.timer.usleep(1000000)
  hs.timer.usleep(1000000)

  assertTrue(type(obj:baudRate()) == "number")

  assertTrue(type(obj:dataBits()) == "number")

  assertTrue(type(obj:parity()) == "string")

  assertTrue(type(obj:path()) == "string")

  assertTrue(type(obj:shouldEchoReceivedData()) == "boolean")

  assertTrue(type(obj:usesDTRDSRFlowControl()) == "boolean")

  assertTrue(type(obj:usesRTSCTSFlowControl()) == "boolean")

  assertTrue(type(obj:stopBits()) == "number")

  obj:sendData("test")

  obj:close()

  hs.timer.usleep(1000000)
  hs.timer.usleep(1000000)

  assertTrue(obj:isOpen() == false)

  return success()
end