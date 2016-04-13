function launchAndReturnAppFromBundleID(bundleID)
  assertTrue(hs.application.launchOrFocusByBundleID(bundleID))
  local runningApps = hs.application.applicationsForBundleID(bundleID)
  assertIsTable(runningApps)
  local app = runningApps[1]
  assertIsUserdata(app)

  return app
end

function testAttributesFromBundleID()
  local bundleID = "com.apple.Safari"
  local appName = "Safari"
  local appPath = "/Applications/Safari.app"

  local app = launchAndReturnAppFromBundleID(bundleID)
  assertIsEqual(appName, app:name())
  assertIsEqual(appPath, app:path())

  assertIsEqual(appName, hs.application.nameForBundleID(bundleID))
  assertIsEqual(appPath, hs.application.pathForBundleID(bundleID))

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
