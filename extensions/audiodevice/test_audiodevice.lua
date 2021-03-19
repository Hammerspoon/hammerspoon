hs.audiodevice = require("hs.audiodevice")

-- Test constructors/functions
function testGetDefaultEffect()
  assertIsUserdataOfType("hs.audiodevice", hs.audiodevice.defaultEffectDevice())
  return success()
end

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
  local devices = hs.audiodevice.allOutputDevices()

  local found = hs.audiodevice.findDeviceByName(devices[1]:name())

  assertIsEqual(devices[1], found)
  assertIsUserdataOfType("hs.audiodevice", found)

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

function testSetDefaultEffect()
  local beforeDevice = hs.audiodevice.defaultEffectDevice()
  assertTrue(beforeDevice:setDefaultEffectDevice())
  local afterDevice = hs.audiodevice.defaultEffectDevice()
  assertIsEqual(beforeDevice, afterDevice)

  return success()
end

function testSetDefaultOutput()
  local beforeDevice = hs.audiodevice.defaultOutputDevice()
  assertTrue(beforeDevice:setDefaultOutputDevice())
  local afterDevice = hs.audiodevice.defaultOutputDevice()
  assertIsEqual(beforeDevice, afterDevice)

  return success()
end

function testSetDefaultInput()
  local beforeDevice = hs.audiodevice.defaultInputDevice()
  assertTrue(beforeDevice:setDefaultInputDevice())
  local afterDevice = hs.audiodevice.defaultInputDevice()
  assertIsEqual(beforeDevice, afterDevice)

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
  local originalVolume = device:volume()
  local wantVolume = 25

  if (type(originalVolume) ~= "number") then
    print("Audiodevice does not support volume. Skipping test due to lack of hardware")
    return success()
  end

  -- Set the volume to 0 and test if we can set it to a high value
  assertTrue(device:setVolume(0))
  assertTrue(device:setVolume(wantVolume))

  assertIsAlmostEqual(wantVolume, device:volume(), 2)

  -- Be nice and put the volume back where we found it
  device:setVolume(originalVolume)

  return success()
end

function testInputVolume()
  local device = hs.audiodevice.defaultInputDevice()
  local originalVolume = device:inputVolume()
  local wantVolume = 25

  if (type(originalVolume) ~= "number") then
    print("Audiodevice does not support volume. Skipping test due to lack of hardware")
    return success()
  end

  -- Set the volume to 0 and test if we can set it to a high value
  assertTrue(device:setInputVolume(0))
  assertTrue(device:setInputVolume(wantVolume))

  assertIsAlmostEqual(wantVolume, device:inputVolume(), 2)

  -- Be nice and put the volume back where we found it
  device:setInputVolume(originalVolume)

  return success()
end

function testOutputVolume()
  local device = hs.audiodevice.defaultOutputDevice()
  local originalVolume = device:outputVolume()
  local wantVolume = 25

  if (type(originalVolume) ~= "number") then
    print("Audiodevice does not support volume. Skipping test due to lack of hardware")
    return success()
  end

  -- Set the volume to 0 and test if we can set it to a high value
  assertTrue(device:setOutputVolume(0))
  assertTrue(device:setOutputVolume(wantVolume))

  assertIsAlmostEqual(wantVolume, device:outputVolume(), 2)

  -- Be nice and put the volume back where we found it
  device:setOutputVolume(originalVolume)

  return success()
end

function testWatcher()
  local device = hs.audiodevice.defaultOutputDevice()

  -- Call this first so we exercise the codepath for "there is no callback set"
  assertIsNil(device:watcherStart())

  assertIsUserdataOfType("hs.audiodevice", device:watcherCallback(function(a,b,c,d) print("hs.audiodevice watcher callback, this will never be called") end))
  assertFalse(device:watcherIsRunning())

  assertIsUserdataOfType("hs.audiodevice", device:watcherStart())
  assertTrue(device:watcherIsRunning())

  -- Call this again so we exercise the codepath for "the watcher is already running"
  assertIsUserdataOfType("hs.audiodevice", device:watcherStart())

  assertIsUserdataOfType("hs.audiodevice", device:watcherStop())
  assertFalse(device:watcherIsRunning())

  assertIsUserdataOfType("hs.audiodevice", device:watcherCallback(nil))

  return success()
end

testWatcherCallbackSuccess = false

function testWatcherCallback()
  local device = hs.audiodevice.defaultOutputDevice()
  device:watcherCallback(function(uid, eventName, eventScope, eventElement)
                           print("testWatcherCallback callback fired: uid:'"..uid.."' eventName:'"..eventName.."' eventScope:'"..eventScope.."' eventElement:'"..eventElement.."'")
                           testWatcherCallbackSuccess = true
                         end)
  device:watcherStart()

  device:setMuted(not device:muted())
  -- Be nice and put it back
  device:setMuted(not device:muted())
end

function testWatcherCallbackResult()
  if testWatcherCallbackSuccess then
    return success()
  else
    return "Waiting for success..."
  end
end

function testInputSupportsDataSources()
  local input = hs.audiodevice.findInputByName("Built-in Microphone")
  if not input then
    print("Host does not have an internal microphone. Skipping due to lack of hardware")
  else
    assertTrue(input:supportsInputDataSources())
  end

  local output = hs.audiodevice.findOutputByName("Built-in Output") or hs.audiodevice.findOutputByName("Mac Pro Speakers")
  assertFalse(output:supportsInputDataSources())

  return success()
end

function testOutputSupportsDataSources()
  local output = hs.audiodevice.findOutputByName("Built-in Output") or hs.audiodevice.findOutputByName("Mac Pro Speakers")
  assertTrue(output:supportsOutputDataSources())

  local input = hs.audiodevice.findInputByName("Built-in Microphone")
  if not input then
    print("Host does not have an internal microphone. Skipping due to lack of hardware")
  else
    assertFalse(input:supportsOutputDataSources())
  end

  return success()
end

function testCurrentInputDataSource()
  local device = hs.audiodevice.findInputByName("Built-in Microphone")
  if not device then
    print("Host does not have an internal microphone. Skipping due to lack of hardware")
  else
    local dataSource = device:currentInputDataSource()
    assertIsUserdataOfType("hs.audiodevice.datasource", dataSource)
  end

  return success()
end

function testCurrentOutputDataSource()
  local device = hs.audiodevice.findOutputByName("Built-in Output") or hs.audiodevice.findOutputByName("Mac Pro Speakers")
  local dataSource = device:currentOutputDataSource()
  assertIsUserdataOfType("hs.audiodevice.datasource", dataSource)

  return success()
end

function testAllInputDataSources()
  local device = hs.audiodevice.findInputByName("Built-in Microphone")
  if not device then
    print("Host does not have an internal microphone. Skipping due to lack of hardware")
    return success()
  end

  local sources = device:allInputDataSources()
  assertIsTable(sources)
  assertGreaterThanOrEqualTo(1, #sources)

  return success()
end

function testAllOutputDataSources()
  local device = hs.audiodevice.findOutputByName("Built-in Output") or hs.audiodevice.findOutputByName("Mac Pro Speakers")
  local sources = device:allOutputDataSources()
  assertIsTable(sources)
  assertGreaterThanOrEqualTo(1, #sources)

  return success()
end

-- hs.audiodevice.datasource methods
function testDataSourceToString()
  local device = hs.audiodevice.findOutputByName("Built-in Output") or hs.audiodevice.findOutputByName("Mac Pro Speakers")
  local source = device:currentOutputDataSource()
  assertIsString(tostring(source))

  return success()
end

function testDataSourceName()
  local outputDevice = hs.audiodevice.findOutputByName("Built-in Output") or hs.audiodevice.findOutputByName("Mac Pro Speakers")
  local outputDataSource = outputDevice:currentOutputDataSource()
  assertIsString(outputDataSource:name())

  local inputDevice = hs.audiodevice.findInputByName("Built-in Microphone")
  if not inputDevice then
    print("Host does not have an internal microphone. Skipping due to lack of hardware")
  else
    local inputDataSource = inputDevice:currentInputDataSource()
    assertIsString(inputDataSource:name())
  end

  return success()
end

function testDataSourceSetDefault()
  local outputDevice = hs.audiodevice.findOutputByName("Built-in Output") or hs.audiodevice.findOutputByName("Mac Pro Speakers")
  local outputDataSourceBefore = outputDevice:currentOutputDataSource()
  assertIsUserdataOfType("hs.audiodevice.datasource", outputDataSourceBefore:setDefault())
  local outputDataSourceAfter = outputDevice:currentOutputDataSource()
  assertIsEqual(outputDataSourceBefore, outputDataSourceAfter)

  local inputDevice = hs.audiodevice.findInputByName("Built-in Microphone")
  if not inputDevice then
    print("Host does not have an internal microphone. Skipping due to lack of hardware")
    return success()
  end

  local inputDataSourceBefore = inputDevice:currentInputDataSource()
  assertIsUserdataOfType("hs.audiodevice.datasource", inputDataSourceBefore:setDefault())
  local inputDataSourceAfter = inputDevice:currentInputDataSource()
  assertIsEqual(inputDataSourceBefore, inputDataSourceAfter)

  return success()
end

