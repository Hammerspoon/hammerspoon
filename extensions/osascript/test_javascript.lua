hs.osascript = require("hs.osascript")

function testJavaScriptParseError()
  local js = "2 +"
  local status, object, descriptor = hs.osascript.javascript(js)
  assertFalse(status)
  assertIsEqual(descriptor.OSAScriptErrorBriefMessageKey, "Error on line 1: SyntaxError: Unexpected end of script")
  return success()
end

function testJavaScriptAddition()
  local js = "2+2"
  local status, object, descriptor = hs.osascript.javascript(js)
  assertTrue(status)
  assertIsEqual(object, 4)
  return success()
end

function testJavaScriptDestructuring()
  local js = [[
    var obj = { cat: 1, dog: 2 };
    var { cat, dog } = obj;
    cat + dog;
]]
  local status, object, descriptor = hs.osascript.javascript(js)
  assertTrue(status)
  assertIsEqual(object, 3)
  return success()
end

function testJavaScriptString()
  local js = [[
    var str1 = "Hello", str2 = "World";
    str1 + ", " + str2 + "!";
]]
  local status, object, descriptor = hs.osascript.javascript(js)
  assertTrue(status)
  assertIsEqual(object, "Hello, World!")
  return success()
end

function testJavaScriptArray()
  local js = [[
    [1, "a", 3.14, "b", null, false]
]]
  local status, object, descriptor = hs.osascript.javascript(js)
  assertTrue(status)
  assertIsEqual(object[1], 1)
  assertIsEqual(object[2], "a")
  assertIsEqual(object[3], 3.14)
  assertIsEqual(object[4], "b")
  assertIsEqual(object[5], false)
  return success()
end

function testJavaScriptJsonStringify()
  local js = [[
    var obj = {
      a: 1,
      "b": "two",
      "c": true
    };
    json = JSON.stringify(obj);
    json;
]]
  local status, object, descriptor = hs.osascript.javascript(js)
  assertTrue(status)
  assertIsEqual(object, '{"a":1,"b":"two","c":true}')
  return success()
end

function testJavaScriptJsonParse()
  local js = [[
    var json = '{"a":1, "b": "two", "c": true}';
    obj = JSON.parse(json);
    obj;
]]
  local status, object, descriptor = hs.osascript.javascript(js)
  assertIsEqual(status, true)
  assertIsEqual(object.a, 1)
  assertIsEqual(object.b, "two")
  assertIsEqual(object.c, true)
  return success()
end

function testJavaScriptJsonParseError()
  local js = [[
    var json = '{"a":1, "b": "two", c: true}';
    obj = JSON.parse(json);
    obj;
]]
  local status, object, descriptor = hs.osascript.javascript(js)
  assertFalse(status)
  assertIsEqual("Error", descriptor.OSAScriptErrorMessageKey and descriptor.OSAScriptErrorMessageKey:sub(1, 5))
  return success()
end
