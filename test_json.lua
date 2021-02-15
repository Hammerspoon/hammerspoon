local testTable = {
  first = 1,
  second = "two"
}

function testEncodeDecode()
  local encoded = hs.json.encode(testTable)
  assertTablesEqual(testTable, hs.json.decode(encoded))

  local encodedPP = hs.json.encode(testTable, true)
  assertTablesEqual(testTable, hs.json.decode(encodedPP))

  return success()
end

function testReadWrite()
  assertTrue(hs.json.write(testTable, "/tmp/hsjsontest.txt", false, true))
  local decoded = hs.json.read("/tmp/hsjsontest.txt")

  assertTablesEqual(testTable, decoded)

  return success()
end
