-- Test constructors/functions
function testGetDefaultOutput()
  assertIsUserdataOfType("hs.audiodevice", hs.audiodevice.defaultOutputDevice())
  return success()
end

function testGetDefaultInput()
  assertIsUserdataOfType("hs.audiodevice", hs.audiodevice.defaultInputDevice())
  return success()
end

function testGetCurrentOutput()
  local current = hs.audiodevice.current()
  assertIsTable(current)
  assertIsUserdataOfType("hs.audiodevice", current["device"])
  return success()
end

function testGetCurrentInput()
  local current = hs.audiodevice.current(true)
  assertIsTable(current)
  assertIsUserdataOfType("hs.audiodevice", current["device"])
  return success()
end

function testGetAllDevices()
  assertTableNotEmpty(hs.audiodevice.allDevices())
  return success()
end

function testGetAllInputDevices()
  assertTableNotEmpty(hs.audiodevice.allInputDevices())
  return success()
end

function testGetAllOutputDevices()
  assertTableNotEmpty(hs.audiodevice.allOutputDevices())
  return success()
end

function testFindDeviceByName()
  assertIsUserdataOfType("hs.audiodevice", hs.audiodevice.findDeviceByName("Built-in Output"))
  return success()
end

function testFindDeviceByUID()
  local device = hs.audiodevice.defaultOutputDevice()
  assertIsEqual(device, hs.audiodevice.findDeviceByUID(device:uid()))
  return success()
end

function testFindInputByName()
  local device = hs.audiodevice.defaultInputDevice()
  local foundDevice = hs.audiodevice.findInputByName(device:name())
  assertIsEqual(device, foundDevice)
  return success()
end

function testFindInputByUID()
  local device = hs.audiodevice.defaultInputDevice()
  local foundDevice = hs.audiodevice.findInputByUID(device:uid())
  assertIsEqual(device, foundDevice)
  return success()
end

function testFindOutputByName()
  local device = hs.audiodevice.defaultOutputDevice()
  local foundDevice = hs.audiodevice.findOutputByName(device:name())
  assertIsEqual(device, foundDevice)
  return success()
end

function testFindOutputByUID()
  local device = hs.audiodevice.defaultOutputDevice()
  local foundDevice = hs.audiodevice.findOutputByUID(device:uid())
  assertIsEqual(device, foundDevice)
  return success()
end

-- Test hs.audiodevice methods
function testToString()
  assertIsString(tostring(hs.audiodevice.defaultOutputDevice()))
  return success()
end

function testName()
  assertIsString(hs.audiodevice.defaultOutputDevice():name())
  return success()
end

function testUID()
  assertIsString(hs.audiodevice.defaultOutputDevice():uid())
  return success()
end

function testIsInputDevice()
  assertTrue(hs.audiodevice.defaultInputDevice():isInputDevice())
  return success()
end

function testIsOutputDevice()
  assertTrue(hs.audiodevice.defaultOutputDevice():isOutputDevice())
  return success()
end

function testMute()
  local device = hs.audiodevice.defaultOutputDevice()
  local wasMuted = device:muted()
  if (type(wasMuted) ~= "boolean") then
    -- This device does not support muting. Not much we can do about it, so log it and move on
    print("Audiodevice does not support muting, unable to test muting functionality. Skipping test due to lack of hardware")
    return success()
  end
  device:setMuted(not wasMuted)
  assertIsEqual(not wasMuted, device:muted())
  -- Be nice to whoever is running the test and restore the original state
  device:setMuted(wasMuted)
  return success()
end

function testJackConnected()
  local jackConnected = hs.audiodevice.defaultOutputDevice():jackConnected()
  if (type(jackConnected) ~= "boolean") then
    print("Audiodevice does not support Jack Sense. Skipping test due to lack of hardware")
  end
  return success()
end

function testTransportType()
  local transportType = hs.audiodevice.defaultOutputDevice():transportType()
  if (type(transportType) ~= "string") then
    print("Audiodevice does not have a transport type. Skipping test due to lack of hardware")
  end
  return success()
end

function testVolume()
  local device = hs.audiodevice.defaultOutputDevice()
  local wasVolume = device:volume()
  local wantVolume = wasVolume + 1

  if (type(wasVolume) ~= "number") then
    print("Audiodevice does not support volume. Skipping test due to lack of hardware")
    return success()
  end

  if (wantVolume > 100) then
    wantVolume = 1
  end

  -- We can't test this properly because the OS sets the volume asynchronously, so we'll just ensure that C thinks it changed, and put it back
  assertTrue(device:setVolume(wantVolume))
  assertTrue(device:setVolume(wasVolume))

  return success()
end

function testWatcher()
  local device = hs.audiodevice.defaultOutputDevice()
  assertIsUserdataOfType("hs.audiodevice", device:watcherCallback(function(a,b,c,d) print("hs.audiodevice watcher callback, this will never be called") end))
  assertFalse(device:watcherIsRunning())

  assertIsUserdataOfType("hs.audiodevice", device:watcherStart())
  assertTrue(device:watcherIsRunning())

  assertIsUserdataOfType("hs.audiodevice", device:watcherStop())
  assertFalse(device:watcherIsRunning())

  return success()
end
