hs.screen = require("hs.screen")
hs.geometry = require("hs.geometry")

function testMainScreen()
  local screen = hs.screen.mainScreen()
  assertIsUserdataOfType("hs.screen", screen)

  return success()
end

function testPrimaryScreen()
  local screen = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", screen)

  return success()
end

function testAllScreens()
  local screens = hs.screen.allScreens()
  assertIsTable(screens)
  assertGreaterThan(0, #screens)

  return success()
end

function testFind()
  local primary = hs.screen.primaryScreen()
  local id = hs.screen.find(primary:id())
  local name = hs.screen.find(primary:name())
  local point = hs.screen.find(primary:frame())
  local size = hs.screen.find(primary:fullFrame())
  local rect = hs.screen.find(primary:frame())
  local uuid = hs.screen.find(primary:getUUID())

  assertIsUserdataOfType("hs.screen", primary)
  assertIsEqual(primary, id)
  assertIsEqual(primary, name)
  assertIsEqual(primary, point)
  assertIsEqual(primary, size)
  assertIsEqual(primary, rect)
  assertIsEqual(primary, uuid)

  return success()
end

function testScreenPositions()
  local positions = hs.screen.screenPositions()
  local i = 0

  for screen,pos in pairs(positions) do
    assertIsUserdataOfType("hs.screen", screen)
    assertIsTable(pos)
    assertIsNumber(pos["x"])
    assertIsNumber(pos["y"])
    i = i + 1
  end

  assertGreaterThan(0, i)

  return success()
end

function testAvailableModes()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  local modes = primary:availableModes()
  assertIsTable(modes)

  local i = 0

  for modeName,mode in pairs(modes) do
    assertIsString(modeName)
    assertIsNumber(mode["w"])
    assertIsNumber(mode["h"])
    assertIsNumber(mode["scale"])
    i = i + 1
  end

  assertGreaterThan(0, i)

  return success()
end

function testCurrentMode()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  local mode = primary:currentMode()
  assertIsTable(mode)

  assertIsNumber(mode["w"])
  assertIsNumber(mode["h"])
  assertIsNumber(mode["scale"])
  assertIsString(mode["desc"])

  return success()
end

function testFrames()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  local frame = primary:frame()
  assertIsTable(frame)
  assertIsEqual("rect", frame:type())

  local fullFrame = primary:fullFrame()
  assertIsTable(frame)
  assertIsEqual("rect", frame:type())

  return success()
end

function testFromUnitRect()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  local frame = primary:frame()
  local unitFrame = primary:fromUnitRect(hs.geometry.unitrect(0, 0, 1, 1))

  assertIsEqual(frame, unitFrame)

  return success()
end

function testBrightness()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  local brightness = primary:getBrightness()

  if type(brightness) == "nil" then
    print("Screen does not support brightness, skipping test due to lack of hardware")
    return success()
  end

  assertIsNumber(brightness)
  assertGreaterThanOrEqualTo(0, brightness)
  assertLessThanOrEqualTo(1, brightness)

  local result = primary:setBrightness(1)
  assertIsEqual(primary, result)
  assertIsEqual(1, primary:getBrightness())

  local result = primary:setBrightness(0)
  assertIsEqual(primary, result)
  assertIsEqual(0, primary:getBrightness())

  -- Be nice and put the original brightness back
  primary:setBrightness(brightness)

  return success()
end

function testGamma()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  local gamma = primary:getGamma()
  assertIsTable(gamma)

  assertGreaterThanOrEqualTo(0, gamma["whitepoint"]["red"])
  assertGreaterThanOrEqualTo(0, gamma["whitepoint"]["green"])
  assertGreaterThanOrEqualTo(0, gamma["whitepoint"]["blue"])
  assertGreaterThanOrEqualTo(0, gamma["blackpoint"]["red"])
  assertGreaterThanOrEqualTo(0, gamma["blackpoint"]["green"])
  assertGreaterThanOrEqualTo(0, gamma["blackpoint"]["blue"])

  assertLessThanOrEqualTo(1, gamma["whitepoint"]["red"])
  assertLessThanOrEqualTo(1, gamma["whitepoint"]["green"])
  assertLessThanOrEqualTo(1, gamma["whitepoint"]["blue"])
  assertLessThanOrEqualTo(1, gamma["blackpoint"]["red"])
  assertLessThanOrEqualTo(1, gamma["blackpoint"]["green"])
  assertLessThanOrEqualTo(1, gamma["blackpoint"]["blue"])

  local newGamma = {
      whitepoint = {
          red = 0.468,
          green = 0.468,
          blue = 0.468
      },
      blackpoint = {
          red = 0.223,
          green = 0.223,
          blue = 0.223
      }
  }

  assertTrue(primary:setGamma(newGamma["whitepoint"], newGamma["blackpoint"]))

  -- Commented out because this should be an async test
  --local checkGamma = primary:getGamma()
  --assertIsTable(checkGamma)

  --assertIsAlmostEqual(0.468, checkGamma["whitepoint"]["red"], 0.01)
  --assertIsAlmostEqual(0.468, checkGamma["whitepoint"]["green"], 0.01)
  --assertIsAlmostEqual(0.468, checkGamma["whitepoint"]["blue"], 0.01)
  --assertIsAlmostEqual(0.223, checkGamma["blackpoint"]["red"], 0.01)
  --assertIsAlmostEqual(0.223, checkGamma["blackpoint"]["green"], 0.01)
  --assertIsAlmostEqual(0.223, checkGamma["blackpoint"]["blue"], 0.01)

  -- Be nice and put the gamma pack
  primary:setGamma(gamma["whitepoint"], gamma["blackpoint"])

  return success()
end

function testId()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)
  assertIsNumber(primary:id())

  return success()
end

function testName()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)
  assertIsString(primary:name())

  return success()
end

function testPosition()
  local screens = hs.screen.allScreens()
  for _,screen in pairs(screens) do
    local x, y = screen:position()
    assertIsNumber(x)
    assertIsNumber(y)
  end

  return success()
end

function testNextPrevious()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)
  assertIsUserdataOfType("hs.screen", primary:next())
  assertIsUserdataOfType("hs.screen", primary:previous())

  return success()
end

function testRotation()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  local origRotation = primary:rotate()
  assertIsNumber(origRotation)

  assertTrue(primary:rotate(90))
  --assertIsEqual(90, primary:rotate())
  assertTrue(primary:rotate(180))
  --assertIsEqual(180, primary:rotate())

  -- Be nice and put the screen back
  primary:rotate(origRotation)

  return success()
end

function testSetMode()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  local mode = primary:currentMode()
  assertTrue(primary:setMode(mode["w"], mode["h"], mode["scale"], mode["freq"], mode["depth"]))

  return success()
end

function testSetOrigin()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  local origin = primary:fullFrame()
  assertTrue(primary:setOrigin(origin["_x"], origin["_y"]))

  return success()
end

function testSetPrimary()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  -- This is effectively a no-op, because we don't bother to do the work if the screen is already primary, but that's a codepath, so let's test it
  assertTrue(primary:setPrimary())

  local screens = hs.screen.allScreens()

  if (#screens == 1) then
    print("Skipping complex hs.screen:setPrimary() test due to a lack of available screens")
    return success()
  end

  assertTrue(screens[2]:setPrimary())
  assertIsEqual(screens[2], hs.screen.primaryScreen())

  -- Be nice and put the screen back
  primary:setPrimary()

  return success()
end

function testScreenshots()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  assertIsUserdataOfType("hs.image", primary:snapshot())

  local filename = string.format("/tmp/Hammerspoon_test_screenshot_%d", hs.processInfo["processID"])

  primary:shotAsJPG(filename)
  local fd = io.open(filename, "r")
  assertIsNotNil(fd)
  fd:close()
  os.remove(filename)

  primary:shotAsPNG(filename)
  local fd = io.open(filename, "r")
  assertIsNotNil(fd)
  fd:close()
  os.remove(filename)

  return success()
end

function testToUnitRect()
  local primary = hs.screen.primaryScreen()
  assertIsUserdataOfType("hs.screen", primary)

  local unitRect = primary:toUnitRect(primary:fullFrame())

  assertIsEqual(unitRect.x, 0.0)
  assertIsEqual(unitRect.y, 0.0)
  assertIsEqual(unitRect.w, 1.0)
  assertIsEqual(unitRect.h, 1.0)

  return success()
end
