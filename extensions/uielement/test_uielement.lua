hs.uielement = require("hs.uielement")
hs.window = require("hs.window")
hs.timer = require("hs.timer")
hs.eventtap = require("hs.eventtap")
hs.application = require("hs.application")

app = nil
elem = nil
elemEvent = nil
watcher = nil

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

function testWindowWatcherValues()
  assertIsNotNil(elem)
  elem:move({1,1})

  if (type(elemEvent) == "string" and elemEvent == "AXWindowMoved") then
    app:kill()
    return success()
  else
    return "Waiting for success..."
  end
end

function testWindowWatcher()
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

  assertIsNotNil(watcher)
  assertIsEqual(watcher, watcher:start({hs.uielement.watcher.windowMoved}))
  assertIsEqual(elem, watcher:element())

  return success()
end

function testApplicationWatcherValues()
  assertIsNotNil(elem)
  elem:hide()

  if (type(elemEvent) == "string" and elemEvent == hs.uielement.watcher.applicationHidden) then
    elem:kill()
    return success()
  else
    return "Waiting for success..."
  end
end

function testApplicationWatcher()
  elem = hs.application.open("com.apple.systempreferences", 5, true)
  assertIsUserdataOfType("hs.application", elem)

  watcher = elem:newWatcher(function(element, event, thisWatcher, userdata)
        elemEvent = event
        assertIsEqual(watcher, thisWatcher:stop())
  end)

  assertIsNotNil(watcher)
  assertIsEqual(watcher, watcher:start({hs.uielement.watcher.applicationHidden}))
  assertIsEqual(elem, watcher:element())

  return success()
end

function testUIelementWatcherValues()
    assertIsNotNil(elem)
    app:kill()

    if (type(elemEvent) == "string" and elemEvent == hs.uielement.watcher.elementDestroyed) then
        return success()
    else
        return "Waiting for success... " .. (elemEvent or "(nil)")
    end
end

-- This doesn't work because the elementDestroyed event is not produced for UI widgets.
function testUIelementWatcher()
    assertTrue(hs.accessibilityState(false))
    app = hs.application.open("System Information", 5, true)
    assertIsUserdataOfType("hs.application", app)
    hs.timer.usleep(500000)
    assertTrue(hs.application.launchOrFocus("System Information"))

    elem = hs.uielement.focusedElement()
    assertIsNotNil(elem)
    assertIsString(elem:role())

    watcher = elem:newWatcher(function(element, event, thisWatcher, userdata)
        hs.alert.show("watcher-callback")
        elemEvent = event
        assertIsEqual(watcher, thisWatcher:stop())
    end)

    assertIsNotNil(watcher)
    assertIsEqual(watcher, watcher:start({hs.uielement.watcher.elementDestroyed}))
    assertIsEqual(elem, watcher:element())

    return success()
end
