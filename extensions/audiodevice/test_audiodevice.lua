function testGetDefaultOutput()
  local defOutput = hs.audiodevice.defaultOutputDevice()
  local meta = getmetatable(defOutput)
  return meta['__type']
end

function testGetDefaultInput()
  local defInput = hs.audiodevice.defaultInputDevice()
  local meta = getmetatable(defInput)
  return meta['__type']
end