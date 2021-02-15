local testTable = {
  first = 1,
  second = "two"
}
local emptyTable = {}
local notATable = "I am not a table"

function testEncodeDecode()
  local encoded = hs.json.encode(testTable)
  assertTablesEqual(testTable, hs.json.decode(encoded))

  local encodedPP = hs.json.encode(testTable, true)
  assertTablesEqual(testTable, hs.json.decode(encodedPP))

  assertIsEqual("[]", hs.json.encode(emptyTable))

  return success()
end

function testEncodeDecodeFailures()
  hs.json.encode(notATable)

  return success()
end

function testReadWrite()
  assertTrue(hs.json.write(testTable, "/tmp/hsjsontest.txt", false, true))
  local decoded = hs.json.read("/tmp/hsjsontest.txt")

  assertTablesEqual(testTable, decoded)

  return success()
end
