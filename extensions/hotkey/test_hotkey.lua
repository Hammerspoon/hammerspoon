hs.hotkey = require("hs.hotkey")

-- Storage for a hotkey object in various tests
testHotkey = nil
-- Storage for hotkey callbacks to modify in various tests
testHotkeyValue = nil

function testAssignable()
  assertFalse(hs.hotkey.assignable({"ctrl"}, "Up"))
  assertTrue(hs.hotkey.assignable({"ctrl", "option", "cmd"}, "F"))

  return success()
end

function testGetHotkeys()
  assertTablesEqual(hs.hotkey.getHotkeys(), {})

  return success()
end

function testGetSystemAssigned()
  assertTablesEqual(hs.hotkey.systemAssigned({"ctrl"}, "Up"), {
  enabled = false,
  keycode = 126,
  mods = 4096
})

  return success()
end

function testBasicHotkey()
  testHotkeyValue = 0

  -- Set pressedfn and releasedfn so we can test both work
  testHotkey = hs.hotkey.bind({"ctrl"}, "f", function()
    testHotkeyValue = testHotkeyValue + 1
  end, function()
    testHotkeyValue = testHotkeyValue + 1
  end)

  assertIsString(tostring(testHotkey))
  hs.eventtap.keyStroke({"ctrl"}, "f")

  return success()
end

function testBasicHotkeyValues()
  assertIsEqual(testHotkeyValue, 2)

  return success()
end


function testRepeatingHotkey()
  testHotkeyValue = 0

  testHotkey = hs.hotkey.bind({"ctrl"}, "f", nil, nil, function()
    testHotkeyValue = testHotkeyValue + 1
  end)

  hs.eventtap.event.newKeyEvent({"ctrl"}, "f", true):post()

  return success()
end

function testRepeatingHotkeyValues()
  if testHotkeyValue > 20 then
    hs.eventtap.event.newKeyEvent({"ctrl"}, "f", false):post()
    return success()
  else
    return "Waiting for success... "..tostring(testHotkeyValue)
  end
end


function testHotkeyStates()
  testHotkeyValue = -1

  testHotkey = hs.hotkey.bind({"ctrl"}, "f", function()
    if testHotkeyValue == 3 then
      testHotkeyValue = 4
    else
      testHotkeyValue = 1
    end
  end)

  assertIsTable(testHotkey)

  return success()
end

function testHotkeyStatesValues()
  if testHotkeyValue == 4 then
    testHotkey:delete()
    assertTablesEqual(testHotkey, {})
    return success()
  end

  if testHotkeyValue == -1 then
    hs.eventtap.keyStroke({"ctrl"}, "f")
    return "First iteration, waiting for success..."
  end

  if testHotkeyValue == 1 then
    testHotkey:disable()
    assertFalse(testHotkey.enabled)
    testHotkeyValue = 2
    hs.eventtap.keyStroke({"ctrl"}, "f")
    return "Second iteration, waiting for success..."
  end

  if testHotkeyValue == 2 then
    testHotkey:enable()
    assertTrue(testHotkey.enabled)
    testHotkeyValue = 3
    hs.eventtap.keyStroke({"ctrl"}, "f")
    return "Third iteration, waiting for success..."
  end

  return "This should never happen, this test is broken."
end
