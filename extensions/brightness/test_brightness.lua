hs.brightness = require("hs.brightness")

function testGet()
  local value = hs.brightness.get()
  assertIsNumber(value)
  return success()
end

function testSet()
  local value = hs.brightness.get()
  hs.brightness.set(0)
  assertIsEqual(0, hs.brightness.get())
  hs.brightness.set(50)
  assertIsEqual(50, hs.brightness.get())
  hs.brightness.set(100)
  assertIsEqual(100, hs.brightness.get())

  -- Be polite and put the brightness back where it was
  hs.brightness.set(value)

  return success()
end

function testAmbient()
  local value = hs.brightness.ambient()
  assertIsNumber(value)
  return success()
end
