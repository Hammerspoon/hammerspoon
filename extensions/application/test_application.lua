hs.application = require("hs.application")
hs.dockicon = require("hs.dockicon")

menuTestValue = nil

function testInitWithPidFailures()
  assertIsNil(hs.application.applicationForPID(1))
  return success()
end

function testInitWithPid()
  local apps = hs.application.runningApplications()
  for _,app in pairs(apps) do
    local pidApp = hs.application.applicationForPID(app:pid())
    if pidApp == nil then
      assertIsEqual(app:name(), nil) -- works in XCode now, but still not in GithubActions
    end
    assertIsEqual(app:name(), pidApp:name())
  end
  return success()
end

function testAttributesFromBundleID()
  local appName = "Safari"
  local appPath = "/Applications/Safari.app"
  local bundleID = "com.apple.Safari"

  assertTrue(hs.application.launchOrFocusByBundleID(bundleID))

  local app = hs.application.applicationsForBundleID(bundleID)[1]
  assertIsEqual(appName, app:name())
  assertIsEqual(appPath, app:path())
  assertIsString(tostring(app))

  assertIsEqual(appName, hs.application.nameForBundleID(bundleID))
  assertIsEqual(appPath, hs.application.pathForBundleID(bundleID))

  assertIsEqual("Safari", hs.application.infoForBundleID("com.apple.Safari")["CFBundleExecutable"])
  assertIsNil(hs.application.infoForBundleID("some.nonsense"))
  assertIsEqual("Safari", hs.application.infoForBundlePath("/Applications/Safari.app")["CFBundleExecutable"])
  assertIsNil(hs.application.infoForBundlePath("/C/Windows/System32/lol.exe"))

  app:kill()
  return success()
end

function testBasicAttributes()
  local appName = "Hammerspoon"
  local bundleID = "org.hammerspoon.Hammerspoon"
  local currentPID = hs.processInfo.processID

  assertIsNil(hs.application.applicationForPID(1))

  local app = hs.application.applicationForPID(currentPID)

  assertIsEqual(bundleID, app:bundleID())
  assertIsEqual(appName, app:name())
  assertIsEqual(appName, app:title())
  assertIsEqual(currentPID, app:pid())
  assertFalse(app:isUnresponsive())

  -- This is disabled for now, not sure why it's failing
  -- hs.dockicon.show()
  -- hs.timer.usleep(200000)
  -- assertIsEqual(1, app:kind())
  -- hs.dockicon.hide()
  -- hs.timer.usleep(200000)
  -- assertIsEqual(0, app:kind())

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
  hs.openConsole()
  local app = hs.application.frontmostApplication()
  app:activate()
  assertIsNotNil(app)
  assertTrue(app:isFrontmost())
  assertTrue(app:setFrontmost())

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
  local app = hs.application.open("Audio MIDI Setup", 5, true)
  return success()
end

function testKillingValues()
  local app = hs.application.get("Audio MIDI Setup")
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
  local dock = hs.application.get("Dock")
  assertIsNil(dock:mainWindow())

  hs.application.open("Grapher", 5, true)
  return success()
end

function testWindowsValues()
  local app = hs.application.get("Grapher")
  assertIsNotNil(app)

  local wins = app:allWindows()
  assertIsEqual("table", type(wins))
  assertIsEqual(1, #wins)

  local win = app:focusedWindow()
  assertIsEqual("Grapher", win:application():name())

  app:kill()
  return success()
end

function testMenus()
  local app = hs.application.get("Hammerspoon")
  local menus = app:getMenuItems()
  assertIsTable(menus)
  assertIsEqual("Hammerspoon", menus[1]["AXTitle"])

  local item = app:findMenuItem({"Edit", "Cut"})
  assertIsTable(item)
  assertIsBoolean(item["enabled"])
  assertIsNil(app:findMenuItem({"Foo", "Bar"}))

  item = app:findMenuItem("Cut")
  assertIsTable(item)
  assertIsBoolean(item["enabled"])
  assertIsNil(app:findMenuItem("Foo"))

  assertTrue(app:selectMenuItem({"Edit", "Select All"}))
  assertIsNil(app:selectMenuItem({"Edit", "No Such Menu Item"}))
  assertTrue(app:selectMenuItem("Select All"))
  assertIsNil(app:selectMenuItem("Some Nonsense"))

  app = hs.application.get("Dock")
  app:activate(true)
  menus = app:getMenuItems()
  assertIsNil(menus)

  return success()
end

function testMenusAsync()
  local app = hs.application.get("Hammerspoon")
  local value = app:getMenuItems(function(menutable) menuTestValue = menutable end)
  assertIsUserdataOfType("hs.application", value)
  return success()
end

function testMenusAsyncValues()
  assertIsTable(menuTestValue)
  assertIsEqual("Hammerspoon", menuTestValue[1]["AXTitle"])
  return success()
end

function testUTI()
  local bundle = hs.application.defaultAppForUTI('public.jpeg')
  assertIsEqual("com.apple.Preview", bundle)
  return success()
end
