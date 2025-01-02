function testRandomFloat()
  local i = 10
   while i > 0 do
     local rand = hs.math.randomFloat()
     assertTrue(rand >= 0)
     assertTrue(rand <= 1)
     i = i - 1
   end
  return success()
end

function testRandomFloatFromRange()
  local i = 10
  while i > 0 do
    local rand = hs.math.randomFloatFromRange(0, 100)
    assertTrue(rand >= 0)
    assertTrue(rand <= 100)
    i = i - 1
  end

  local rand1 = hs.math.randomFloatFromRange(-1, 100)
  assertTrue(rand1 >= -1)
  assertTrue(rand1 <= 100)

  local rand2 = hs.math.randomFloatFromRange(1, 1)
  assertTrue(rand2 == 1)

  local rand3 = hs.math.randomFloatFromRange(100, 1)
  assertIsNil(rand3)

  return success()
end

function testRandomFromRange()
  local rand1 = hs.math.randomFromRange(0, 100)
  assertTrue(rand1 >= 0)
  assertTrue(rand1 <= 100)

  local rand2 = hs.math.randomFromRange(-1, 100)
  assertTrue(rand2 >= -1)
  assertTrue(rand2 <= 100)

  local rand3 = hs.math.randomFromRange(1, 1)
  assertTrue(rand3 == 1)

  local rand4 = hs.math.randomFromRange(1, -1)
  assertIsNil(rand4)

  return success()  
end
