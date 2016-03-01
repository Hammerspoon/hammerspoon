-- Note: This file is shared between LuaSkinTests and Hammerspoon Tests
local bundlePath = ...

if (type(bundlePath) == "string") then
  package.path = bundlePath.."/?.lua"..";"..package.path
else
  print("-- Warning: lsunit.lua running with no bundlePath. This is not an error if your package.path contains a testinit.lua")
end

-- Utility functions
function failure(msg)
  error(string.format("Assertion failure: %s", msg))
end

function success()
  return "Success"
end

function errorMsgEquality(expected, actual)
  return string.format("expected: %s, actual: %s", expected, actual)
end

-- Assertions

-- Equality assertions
function assertIsEqual(expected, actual)
  if type(expected) ~= type(actual) then
    failure(errorMsgEquality(type(expected), type(actual)))
  end
  if expected ~= actual then
    failure(errorMsgEquality(expected, actual))
  end
end

function assertIsAlmostEqual(expected, actual, margin)
  if type(expected) ~= type(actual) then
    failure(errorMsgEquality(type(expected), type(actual)))
  end
  if math.abs(expected - actual) > margin then
    failure(string.format("%s (with margin: %s)", errorMsgEquality(expected, actual), tostring(margin)))
  end
end

-- Comparison assertions
function assertTrue(a)
  if not a then
    failure("expected: true, actual: "..tostring(a))
  end
end

function assertFalse(a)
  if a then
    failure("expected: false, actual: "..tostring(a))
  end
end

function assertIsNil(a)
  if a ~= nil then
    failure("expected: nil, actual: "..tostring(a))
  end
end

function assertIsNotNil(a)
  if a == nil then
    failure("expected: nil, actual: "..tostring(a))
  end
end

function assertGreaterThan(a, b)
  if b <= a then
    failure(string.format("expected: %s > %s", b, a))
  end
end

function assertLessThan(a, b)
  if b >= a then
    failure(string.format("expected: %s < %s", b, a))
  end
end

function assertGreaterThanOrEqualTo(a, b)
  if b < a then
    failure(string.format("expected: %s >= %s", b, a))
  end
end

function assertLessThanOrEqualTo(a, b)
  if b > a then
    failure(string.format("expected: %s <= %s", b, a))
  end
end

-- Type assertions
function assertIsType(a, aType)
  if type(a) ~= aType then
    failure(string.format("expected: %s, actual: %s", aType, type(a)))
  end
end

function assertIsNumber(a)
  assertIsType(a, "number")
end

function assertIsString(a)
  assertIsType(a, "string")
end

function assertIsTable(a)
  assertIsType(a, "table")
end

function assertIsFunction(a)
  assertIsType(a, "function")
end

function assertIsBoolean(a)
  assertIsType(a, "boolean")
end

function assertIsUserdata(a)
  assertIsType(a, "userdata")
end

function assertIsUserdataOfType(aType, a)
  assertIsType(a, "userdata")
  local meta = getmetatable(a)
  assertIsEqual(aType, meta["__type"])
end

-- Table assertions
function assertTableNotEmpty(a)
  assertGreaterThan(0, #a)
end


-- Leave this at the end of the file
print ('-- Test harness lsunit.lua loaded. Loading testinit.lua...')
require('testinit')
