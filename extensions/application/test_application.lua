hs.application = require("hs.application")
hs.dockicon = require("hs.dockicon")

function testAttributesFromBundleID()
  local appName = "Safari"
  local appPath = "/Applications/Safari.app"
  local bundleID = "com.apple.Safari"

  assertTrue(hs.application.launchOrFocusByBundleID(bundleID))

  local app = hs.application.applicationsForBundleID(bundleID)[1]
  assertIsEqual(appName, app:name())
  assertIsEqual(appPath, app:path())

  assertIsEqual(appName, hs.application.nameForBundleID(bundleID))
  assertIsEqual(appPath, hs.application.pathForBundleID(bundleID))

  assertIsEqual("Safari", hs.application.infoForBundleID("com.apple.Safari")["CFBundleExecutable"])
  assertIsEqual("Safari", hs.application.infoForBundlePath("/Applications/Safari.app")["CFBundleExecutable"])

  return success()
end

function testBasicAttributes()
  local appName = "Hammerspoon"
  local bundleID = "org.hammerspoon.Hammerspoon"
  local currentPID = hs.processInfo.processID

  local app = hs.application.applicationForPID(currentPID)

  assertIsEqual(bundleID, app:bundleID())
  assertIsEqual(appName, app:name())
  assertIsEqual(appName, app:title())
  assertIsEqual(currentPID, app:pid())

  hs.dockicon.show()
  assertIsEqual(1, app:kind())
  hs.dockicon.hide()
  assertIsEqual(0, app:kind())

  return success()
end

function testActiveAttributes() 
  -- need to use application.watcher for testing these async events
  local appName = "Stickies"
  local app = hs.application.open(appName, 0, true)

  assertTrue(app:isRunning())
  assertTrue(app:activate())

  assertTrue(app:hide())
  assertTrue(app:isHidden())

  assertTrue(app:unhide())
  assertFalse(app:isHidden())

  assertTrue(app:activate())

  local menuPathBlue = {"Color", "Blue"}
  local menuPathGreen = {"Color", "Green"}
  assertTrue(app:selectMenuItem(menuPathBlue))
  app:selectMenuItem({"Color"})
  assertTrue(app:findMenuItem(menuPathBlue).ticked)
  assertTrue(app:selectMenuItem(menuPathGreen))
  app:selectMenuItem({"Color"})
  assertFalse(app:findMenuItem(menuPathBlue).ticked)
  assertIsEqual(appName, app:getMenuItems()[1].AXTitle)

  return success()
end

function testMetaTable()
  -- hs.application's userdata is not aligned with other HS types (via LuaSkin) because it is old and special
  -- the `__type` field is not currently on hs.application object metatables like everything else
  -- this test should pass but can wait for rewrite
  local app = launchAndReturnAppFromBundleID("com.apple.Safari")
  assertIsUserdataOfType("hs.application", app)

  return success()
end

function testFrontmostApplication()
  local app = hs.application.frontmostApplication()
  assertTrue(app:isFrontmost())

  return success()
end

function testRunningApplications()
  local apps = hs.application.runningApplications()
  assertIsEqual("table", type(apps))
  assertGreaterThan(1, #apps)

  return success()
end

function testHiding()
  hs.application.open("Stickies", 5, true)
  return success()
end

function testHidingValues()
  local app = hs.application.get("Stickies")
  assertIsNotNil(app)
  assertTrue(app:isRunning())

  assertFalse(app:isHidden())
  app:hide()
  hs.timer.usleep(500000)
  assertTrue(app:isHidden())
  app:unhide()
  hs.timer.usleep(500000)
  assertFalse(app:isHidden())

  app:kill9()
  return success()
end

function testKilling()
  local app = hs.application.open("Chess", 5, true)
  return success()
end

function testKillingValues()
  local app = hs.application.get("Chess")
  assertIsNotNil(app)
  assertTrue(app:isRunning())

  app:kill()
  hs.timer.usleep(500000)
  assertFalse(app:isRunning())

  return success()
end

function testForceKilling()
  hs.application.open("Calculator", 5, true)
  return success()
end

function testForceKillingValues()
  local app = hs.application.get("Calculator")
  assertIsNotNil(app)
  assertTrue(app:isRunning())

  app:kill9()
  hs.timer.usleep(500000)
  assertFalse(app:isRunning())

  return success()
end

function testWindows()
  hs.application.open("Grapher", 5, true)
  return success()
end

function testWindowsValues()
  local app = hs.application.get("Grapher")
  assertIsNotNil(app)

  local wins = app:allWindows()
  assertIsEqual("table", type(wins))
  assertIsEqual(1, #wins)

  app:kill()
  return success()
end
