hs.appfinder = require("hs.appfinder")

function testAppFromName()
  local app = hs.appfinder.appFromName("Finder")
  assertIsUserdata(app)
  assertIsEqual("Finder", app:name())

  assertIsNil(hs.appfinder.appFromName("Non-never-not-existingApp"))

  return success()
end

function testAppFromWindowTitle()
  hs.openConsole()
  local app = hs.appfinder.appFromWindowTitle("Hammerspoon Console")
  assertIsUserdata(app)
  assertIsEqual("Hammerspoon", app:name())

  assertIsNil(hs.appfinder.appFromWindowTitle("Window title that should never exist"))

  return success()
end

function testAppFromWindowTitlePattern()
  hs.openConsole()
  local app = hs.appfinder.appFromWindowTitlePattern("Ha.* Console")
  assertIsUserdata(app)
  assertIsEqual("Hammerspoon", app:name())

  assertIsNil(hs.appfinder.appFromWindowTitlePattern("Not going .* match"))

  return success()
end

function testWindowFromWindowTitle()
  hs.openConsole()
  local win = hs.appfinder.windowFromWindowTitle("Hammerspoon Console")
  assertIsUserdata(win)
  assertIsEqual("Hammerspoon Console", win:title())

  assertIsNil(hs.appfinder.windowFromWindowTitle("Window title that should never exist"))

  return success()
end

function testWindowFromWindowTitlePattern()
  hs.openConsole()
  local win = hs.appfinder.windowFromWindowTitlePattern("Ha.*Console")
  assertIsUserdata(win)
  assertIsEqual("Hammerspoon Console", win:title())

  assertIsNil(hs.appfinder.windowFromWindowTitlePattern("Not going .* match"))

  return success()
end
