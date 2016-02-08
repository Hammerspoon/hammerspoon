function testParseError()
  local js = "2 +"
  local status, result = hs.javascript(js)
  assertFalse(status)
  assertIsTable(result)
  return success()
end

function testAddition()
  local js = "2+2"
  local status, result = hs.javascript(js)
  assertTrue(status)
  assertIsEqual(result, 4)
  return success()
end

function testDestructuring()
  local js = [[
    var obj = { cat: 1, dog: 2 };
    var { cat, dog } = obj;
    cat + dog;
]]
  local status, result = hs.javascript(js)
  assertTrue(status)
  assertIsEqual(result, 3)
  return success()
end

function testString()
  local js = [[
    var str1 = "Hello", str2 = "World";
    str1 + ", " + str2 + "!";
]]
  local status, result = hs.javascript(js)
  assertTrue(status)
  assertIsEqual(result, "Hello, World!")
  return success()
end

function testJsonStringify()
  local js = [[
    var obj = {
      a: 1, 
      "b": "two", 
      "c": true
    };
    json = JSON.stringify(obj);
    json;
]]
  local status, result = hs.javascript(js)
  assertTrue(status)
  assertIsEqual(result, '{\\"a\\":1,\\"b\\":\\"two\\",\\"c\\":true}')
  return success()
end

-- function testJsonParse()
--   local js = [[
--     var json = '{"a":1, "b": "two", "c": true}';
--     obj = JSON.parse(json);
--     obj;
-- ]]
--   local status, result = hs.javascript(js)
--   assertIsEqual(status, true)
--   assertIsEqual(result, ) -- need to parse NSAppleEventDescriptor nonsense 
--   return success()
-- end

function testJsonParseError()
  local js = [[
    var json = '{"a":1, "b": "two", c: true}';
    obj = JSON.parse(json);
    obj;
]]
  local status, result = hs.javascript(js)
  assertFalse(status)
  assertIsEqual(result.OSAScriptErrorBriefMessageKey, "Error on line 2: SyntaxError: JSON Parse error: Property name must be a string literal")
  return success()
end
