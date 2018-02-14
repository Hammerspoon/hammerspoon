function testAllWindows()
  local allWindows = hs.window.allWindows()
  assertIsEqual("table", type(allWindows))
  assertGreaterThan(1, #allWindows)
  -- Enable this when hs.window objects have a proper __type metatable entry
  -- assertIsUserdataOfType(allWindows[1], "hs.window")

  return success()
end

function testDesktop()
  local desktop = hs.window.desktop()
  assertIsNotNil(desktop)
  assertIsEqual("AXScrollArea", desktop:role())
  return success()
end

function testOrderedWindows()
  hs.openConsole() -- Make sure we have at least one window
  local orderedWindows = hs.window.orderedWindows()
  assertIsEqual("table", type(orderedWindows))
  assertGreaterThan(1, #orderedWindows)
  return success()
end
