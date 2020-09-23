require("hs.timer")

function testAllWindows()
  hs.openConsole()
  hs.openPreferences()
  local allWindows = hs.window.allWindows()
  assertIsEqual("table", type(allWindows))
  assertGreaterThan(1, #allWindows)
  -- Enable this when hs.window objects have a proper __type metatable entry
  -- assertIsUserdataOfType(allWindows[1], "hs.window")

  hs.closePreferences()
  hs.closeConsole()
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
  hs.openPreferences()

  hs.application.launchOrFocus("Activity Monitor.app")
  hs.application.launchOrFocus("System Information.app")
  local orderedWindows = hs.window.orderedWindows()
  assertIsEqual("table", type(orderedWindows))
  --assertIsEqual(hs.inspect(orderedWindows) .. " :: " .. hs.inspect(hs.window.visibleWindows()) .. " :: " .. hs.inspect(hs.window._orderedwinids()), "lol")
  hs.timer.usleep(500000)
  local activityMonitor = hs.application.get("Activity Monitor")
  if (activityMonitor) then
    activityMonitor:kill()
  end
  local systemInformation = hs.application.get("System Information")
  if (systemInformation) then
    systemInformation:kill()
  end
  assertGreaterThan(1, #orderedWindows)
  return success()
end

function testFocusedWindow()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  assertIsUserdataOfType("hs.window", win)
  return success()
end

function testSnapshots()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  local id = win:id()
  assertIsNumber(id)
  assertGreaterThan(0, id)
  assertIsUserdataOfType("hs.image", hs.window.snapshotForID(id))
  assertIsUserdataOfType("hs.image", win:snapshot())
  return success()
end

function testTitle()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  local title = win:title()
  assertIsString(title)
  assertIsEqual("Hammerspoon Console", win:title())
  assertIsString(tostring(win))
  return success()
end

function testRoles()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  assertIsEqual("AXWindow", win:role())
  assertIsEqual("AXStandardWindow", win:subrole())
  assertTrue(win:isStandard())
  return success()
end

function testTopLeft()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  local topLeftOrig = win:topLeft()
  assertIsTable(topLeftOrig)
  local topLeftNew = hs.geometry.point(topLeftOrig.x + 1, topLeftOrig.y + 1)
  win:setTopLeft(topLeftNew)
  topLeftNew = win:topLeft()
  assertIsEqual(topLeftNew.x, topLeftOrig.x + 1)
  assertIsEqual(topLeftNew.y, topLeftOrig.y + 1)
  return success()
end

function testSize()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  win:setSize(hs.geometry.size(500, 600))
  local sizeOrig = win:size()
  assertIsTable(sizeOrig)
  assertIsEqual(500, sizeOrig.w)
  assertIsEqual(600, sizeOrig.h)
  local sizeNew = hs.geometry.size(sizeOrig.w + 5, sizeOrig.h + 5)
  win:setSize(sizeNew)
  sizeNew = win:size()
  assertIsEqual(sizeNew.w, sizeOrig.w + 5)
  assertIsEqual(sizeNew.h, sizeOrig.h + 5)
  return success()
end

function testMinimize()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  local isMinimizedOrig = win:isMinimized()
  assertIsBoolean(isMinimizedOrig)
  win:minimize()
  assertFalse(isMinimizedOrig == win:isMinimized())
  win:unminimize()
  assertTrue(isMinimizedOrig == win:isMinimized())
  return success()
end

function testPID()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  assertIsEqual(win:pid(), hs.processInfo["processID"])
  return success()
end

function testApplication()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  local app = win:application()
  assertIsUserdataOfType("hs.application", app) -- This will fail right now, because hs.application doesn't have a __type metatable entry
  return success()
end

function testTabs()
  -- First test tabs on a window that doesn't have tabs
  hs.openConsole()
  local win = hs.window.focusedWindow()
  assertIsUserdata(win)
  assertIsEqual(0, win:tabCount())

  -- Now test an app with tabs
  local safari = hs.application.open("Safari", 5, true)

  -- Ensure we have at least two tabs
  hs.urlevent.openURLWithBundle("http://www.apple.com", "com.apple.Safari")
  hs.urlevent.openURLWithBundle("http://developer.apple.com", "com.apple.Safari")

  local safariWin = safari:mainWindow()
  assertIsUserdata(safariWin)

  local tabCount = safariWin:tabCount()
  assertGreaterThan(1, tabCount)

  safariWin:focusTab(tabCount - 1)

  return success()
end

function testBecomeMain() -- This will fail
end

function testClose()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  assertTrue(win:close())
  -- It would be nice to do something more here, to verify it's gone
  return success()
end

function testFullscreen()
  hs.openConsole()
  local win = hs.window.focusedWindow()
  assertIsUserdata(win)
  local fullscreenState = win:isFullScreen()
  assertIsBoolean(fullscreenState)
  assertFalse(fullscreenState)
  win:setFullScreen(false)

  return success()
end

function testFullscreenOneSetup()
  hs.openConsole()
  local win = hs.window.get("Hammerspoon Console")
  assertIsEqual(win:title(), "Hammerspoon Console")
  assertFalse(win:isFullScreen())

  win:setFullScreen(true)

  return success()
end

function testFullscreenOneResult()
  local win = hs.window.get("Hammerspoon Console")
  assertIsEqual(win:title(), "Hammerspoon Console")
  assertTrue(win:isFullScreen())
  win:setFullScreen(false)

  return success()
end

function testFullscreenTwoSetup()
  hs.openConsole()
  local win = hs.window.get("Hammerspoon Console")
  win:toggleZoom()

  return success()
end

function testFullscreenTwoResult()
  local win = hs.window.get("Hammerspoon Console")
  assertTrue(win:isFullScreen())
  win:setFullScreen(false)

  return success()
end
