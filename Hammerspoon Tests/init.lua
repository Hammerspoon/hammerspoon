-- Function to test that all extensions load correctly
function testrequires()
  failed = {}
  for k,v in pairs(hs._extensions) do
    print(string.format("checking extension '%s'", k))
    res, ext = pcall(load(string.format("return hs.%s", k)))
    if res then
      if type(ext) ~= 'table' then
        failreason = string.format("type of 'hs.%s' is '%s', was expecting 'table'", k, type(ext))
        print(failreason)
        table.insert(failed, failreason)
      end
    else
      failreason = string.format("failed to load 'hs.%s', error was '%s'", k, ext)
      print(failreason)
      table.insert(failed, failreason)
    end
  end
  return table.concat(failed, " / ")
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
print ('testing init.lua loaded')