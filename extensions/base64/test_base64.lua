hs.base64 = require("hs.base64")

function testEncode()
  local original = "encoding test"
  assertIsEqual("ZW5jb2RpbmcgdGVzdA==", hs.base64.encode(original))
  assertIsEqual("ZW5j\nb2Rp\nbmcg\ndGVz\ndA==", hs.base64.encode(original, 4))
  assertIsEqual("MQ==", hs.base64.encode(1))

  -- Check that we still get back a valid encoded string if our width argument is nonsense
  assertIsEqual("MQ==", hs.base64.encode(1, 100))
  assertIsEqual("MQ==", hs.base64.encode(1, -1))

  return success()
end

function testDecode()
  local single = "ZW5jb2RpbmcgdGVzdA=="
  local split = "ZW5j\nb2Rp\nbmcg\ndGVz\ndA=="
  assertIsEqual("encoding test", hs.base64.decode(single))
  assertIsEqual("encoding test", hs.base64.decode(split))

  return success()
end
