hs.uielement = require("hs.uielement")
hs.window = require("hs.window")
hs.timer = require("hs.timer")
hs.eventtap = require("hs.eventtap")
hs.application = require("hs.application")

elem = nil
elemEvent = nil

function getPrefs()
  hs.openPreferences()
  return hs.uielement.focusedElement()
end

function getConsole()
  hs.openConsole()
  return hs.uielement.focusedElement()
end

function testHammerspoonElements()
  local consoleElem = getConsole()
  local consoleElem2 = getConsole()

  assertIsEqual(consoleElem, consoleElem2)

  assertFalse(consoleElem:isApplication())
  assertFalse(consoleElem:isWindow())
  assertIsEqual("AXTextField", consoleElem:role())

  local prefsElem = getPrefs()
  assertFalse(prefsElem:isApplication())
  assertTrue(prefsElem:isWindow())
  assertIsEqual("AXWindow", prefsElem:role())
  assertIsEqual(nil, prefsElem:selectedText())

  local consoleElem2 = getConsole()
  assertFalse(consoleElem:isApplication())
  assertFalse(consoleElem:isWindow())
  assertIsEqual("AXTextField", consoleElem:role())

  assertFalse(consoleElem==prefsElem)
  assertTrue(consoleElem==consoleElem2)

  assertTrue(hs.window.find("Hammerspoon Console"):close())
  assertTrue(hs.window.find("Hammerspoon Preferences"):close())

  return success()
end

function testSelectedText()
  local text = "abc123"
  local textedit = hs.application.open("com.apple.TextEdit")

  hs.timer.usleep(1000000)
  hs.eventtap.keyStroke({"cmd"}, "n")
  hs.timer.usleep(1000000)
  hs.eventtap.keyStrokes(text)
  hs.timer.usleep(20000)
  hs.eventtap.keyStroke({"cmd"}, "a")

  assertIsEqual(text, hs.uielement.focusedElement():selectedText())

  textedit:kill9()

  return success()
end

function testWatcherValues()
  assertIsNotNil(elem)
  elem:move({1,1})

  if (type(elemEvent) == "string" and elemEvent == "AXWindowMoved") then
    app:kill()
    return success()
  else
    return "Waiting for success... (" .. type(elemEvent) .. ")"
  end
end

function testWatcher()
  app = hs.application.open("com.apple.systempreferences", 5, true)
  assertIsUserdataOfType("hs.application", app)

  hs.window.find("System Preferences"):focus()
  elem = hs.window.focusedWindow()
  assertIsNotNil(elem)

  watcher = elem:newWatcher(function(element, event, thisWatcher, userdata)
      hs.alert.show("watcher-callback")
      elemEvent = event
      assertIsEqual(watcher, thisWatcher:stop())
    end)

  assertIsEqual(watcher, watcher:start({hs.uielement.watcher.windowMoved}))
  assertIsEqual(elem, watcher:element())

  return success()
end
