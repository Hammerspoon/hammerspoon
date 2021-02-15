local testTable = {
  first = 1,
  second = "two"
}
local testTableEncoded = '{"second":"two","first":1}'
local testTableEncodedPP = [[{
  "second" : "two",
  "first" : 1
}]]

function testEncode()
  local encoded = hs.json.encode(testTable)
  local encodedPP = hs.json.encode(testTable, true)

  assertIsEqual(testTableEncoded, encoded)
  assertIsEqual(testTableEncodedPP, encodedPP)

  return success()
end

function testDecode()
  local decoded = hs.json.decode(testTableEncoded)
  assertTablesEqual(testTable, decoded)

  return success()
end

function testReadWrite()
  assertTrue(hs.json.write(testTable, "/tmp/hsjsontest.txt", false, true))
  local decoded = hs.json.read("/tmp/hsjsontest.txt")

  assertTablesEqual(testTable, decoded)

  return success()
end
