function testGetDefaultOutput()
  local defOutput = hs.audiodevice.defaultOutputDevice()
  local meta = getmetatable(defOutput)
  return meta['__type']
end