hs.mouse = require("hs.mouse")

function testMouseCount()
    assertGreaterThan(0, hs.mouse.count())
    assertGreaterThan(0, hs.mouse.count(true))
    
    return success()
end

function testMouseNames()
    local names = hs.mouse.names()
    assertIsTable(names)
    assertIsString(names[1])
    
    return success()
end

function testMouseAbsolutePosition()
    local pos = hs.mouse.getAbsolutePosition()
    assertIsTable(pos)
    assertIsNumber(pos.x)
    assertIsNumber(pos.y)
    
    local newPos = hs.geometry.point(pos.x + 1, pos.y + 1)
    hs.mouse.setAbsolutePosition(newPos)

    local afterPos = hs.mouse.getAbsolutePosition()
    assertIsAlmostEqual(newPos.x, afterPos.x, 1)
    assertIsAlmostEqual(newPos.y, afterPos.y, 1)
    
    return success()
end

function testScrollDirection()
    local scrollDir = hs.mouse.scrollDirection()
    assertTrue(scrollDir == "natural" or "normal")
    
    return success()
end

function testMouseTrackingSpeed()
    local originalSpeed = hs.mouse.trackingSpeed()
    assertIsNumber(originalSpeed)
    
    hs.mouse.trackingSpeed(0.0)
    assertIsEqual(0.0, hs.mouse.trackingSpeed())
    
    hs.mouse.trackingSpeed(3.0)
    assertIsEqual(3.0, hs.mouse.trackingSpeed())
    
    hs.mouse.trackingSpeed(originalSpeed)
    
    return success()
end
