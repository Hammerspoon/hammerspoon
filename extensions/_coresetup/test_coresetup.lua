function testOSExit()
  assertIsEqual("function", type(hs._exit))
  assertIsEqual(hs._exit, os.exit)

  return success()
end

function testConfigDir()
  assertIsString(hs.configdir)
  assertTrue(hs.configdir ~= "")

  return success()
end

function testDocstringsJSONFile()
  assertIsString(hs.docstrings_json_file)
  assertTrue(hs.docstrings_json_file ~= "")

  local jsonFD = io.open(hs.docstrings_json_file, "r")
  local json = jsonFD:read("*all")
  assertIsTable(hs.json.decode(json))

  return success()
end

function testProcessInfo()
  assertIsTable(hs.processInfo)
  assertIsString(hs.processInfo["bundleID"])
  assertIsString(hs.processInfo["bundlePath"])
  assertIsString(hs.processInfo["executablePath"])
  assertIsNumber(hs.processInfo["processID"])
  assertIsString(hs.processInfo["resourcePath"])
  assertIsString(hs.processInfo["version"])

  return success()
end

function testShutdownCallback()
  hs.shutdownCallback = shutdownLib.verifyShutdown
  hs.reload()

  return success()
end

function testAccessibilityState()
  local result = hs.accessibilityState(false)
  assertIsBoolean(result)

  return success()
end

function testAutoLaunch()
  local orig = hs.autoLaunch()
  assertIsBoolean(orig)

  assertIsEqual(orig, hs.autoLaunch(orig))
  assertIsEqual(not orig, hs.autoLaunch(not orig))

  -- Be nice and put it back
  hs.autoLaunch(orig)

  return success()
end

function testAutomaticallyCheckForUpdates()
  -- NB It's not safe to actually call the function on a non-release build, so we can just check that it is a function
  assertIsFunction(hs.automaticallyCheckForUpdates)

  return success()
end

function testCheckForUpdates()
  -- NB It is not safe to actually call the function on a non-release build, so we can just check that it is a function
  assertIsFunction(hs.checkForUpdates)

  return success()
end

function testCleanUTF8forConsole()
  local orig = "Simple test string"
  assertIsEqual(orig, hs.cleanUTF8forConsole(orig))

  return success()
end

function testConsoleOnTop()
  local orig = hs.consoleOnTop()
  assertIsBoolean(orig)

  assertIsEqual(orig, hs.consoleOnTop(orig))
  assertIsEqual(not orig, hs.consoleOnTop(not orig))

  -- Be nice and put it back
  hs.consoleOnTop(orig)

  return success()
end

function testDockIcon()
  local orig = hs.dockIcon()
  assertIsBoolean(orig)

  assertIsEqual(orig, hs.dockIcon(orig))
  assertIsEqual(not orig, hs.dockIcon(not orig))

  -- Be nice and put it back
  hs.dockIcon(orig)

  return success()
end

-- Note: This test is not called for the moment, it doesn't seem to work when run from a process under Xcode
function testExecute()
  local output, status, type, rc

  output, status, type, rc = hs.execute("/usr/bin/uname", false)

  assertIsEqual(0, rc)
  assertIsEqual("exit", type)
  assertTrue(status)
  assertIsNotNil(string.find(output, "Darwin"))

  output, status, type, rc = hs.execute("/usr/bin/uname", true)

  assertIsEqual(0, rc)
  assertIsEqual("exit", type)
  assertTrue(status)
  assertIsNotNil(string.find(output, "Darwin"))

  return success()
end

function testGetObjectMetatable()
  require("hs.screen")
  local meta = hs.getObjectMetatable("hs.screen")
  assertIsTable(meta)
  assertIsEqual("hs.screen", meta["__type"])

  return success()
end

function testMenuIcon()
  local orig = hs.menuIcon()
  assertIsBoolean(orig)

  assertIsEqual(orig, hs.menuIcon(orig))
  assertIsEqual(not orig, hs.menuIcon(not orig))

  -- Be nice and put it back
  hs.menuIcon(orig)

  return success()
end
