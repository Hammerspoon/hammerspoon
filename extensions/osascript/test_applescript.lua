hs.osascript = require("hs.osascript")

function testAppleScriptParseError()
  local as = "2 +"
  local status, object, descriptor = hs.osascript.applescript(as)
  assertFalse(status)
  assertIsEqual(descriptor.OSAScriptErrorBriefMessageKey, "Expected expression but found end of script.")
  return success()
end

function testAppleScriptAddition()
  local as = "2+2"
  local status, object, descriptor = hs.osascript.applescript(as)
  assertTrue(status)
  assertIsEqual(object, 4)
  return success()
end

function testAppleScriptString()
  local as = [[
    "Hello, " & "World!"
]]
  local status, object, descriptor = hs.osascript.applescript(as)
  assertTrue(status)
  assertIsEqual(object, "Hello, World!")
  return success()
end

function testAppleScriptArray()
  local as = [[
    [1, "a", 3.14, "b", null, false]
]]
  local status, object, descriptor = hs.osascript.applescript(as)
  assertTrue(status)
  assertIsEqual(object[1], 1)
  assertIsEqual(object[2], "a")
  assertIsEqual(object[3], 3.14)
  assertIsEqual(object[4], "b")
  assertIsEqual(object[5], false)
  return success()
end

function testAppleScriptDict()
  local as = [[
  {a:1, b:"two", c:true}
]]
  local status, object, descriptor = hs.osascript.applescript(as)
  assertIsEqual(status, true)
  assertIsEqual(object.a, 1)
  assertIsEqual(object.b, "two")
  assertIsEqual(object.c, true)
  return success()
end

function testAppleScriptExecutionError()
  local as = [[
  a=1
]]
  local status, object, descriptor = hs.osascript.applescript(as)
  assertFalse(status)
  assertIsEqual(descriptor.OSAScriptErrorBriefMessageKey, "The variable a is not defined.")
  return success()
end
