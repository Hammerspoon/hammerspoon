function typeForObject(anObject)
  local meta = getmetatable(anObject)
  return meta['__type']
end

function assertNonEmptyTable(aTable)
  local result = "Failure"
  if #aTable > 0 then
    result = "Success"
  end
  return result
end

function testGetDefaultOutput()
  assertIsUserdataOfType(hs.audiodevice.defaultOutputDevice(), "hs.audiodevice")
  return success()
end

function testGetDefaultInput()
  assertIsUserdataOfType(hs.audiodevice.defaultInputDevice(), "hs.audiodevice")
  return success()
end

function testGetCurrentOutput()
  local current = hs.audiodevice.current()
  assertIsTable(current)
  assertIsUserdataOfType(current["device"], "hs.audiodevice")
  return success()
end

function testGetCurrentInput()
  local current = hs.audiodevice.current(true)
  assertIsTable(current)
  assertIsUserdataOfType(current["device"], "hs.audiodevice")
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