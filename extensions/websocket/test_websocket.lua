local websocket   = require "hs.websocket"
local timer       = require "hs.timer"

local doAfter     = timer.doAfter

--
-- Variables:
--
TEST_STRING       = "ABC123"
ECHO_URL          = "wss://echo.websocket.org/"
FAKE_URL          = "wss://fake.com/"

--
-- Test creating a new object:
--
function testNew()
  local websocketObject = websocket.new(ECHO_URL, function() end)
  assertIsUserdataOfType("hs.websocket", websocketObject)
  assertTrue(#tostring(websocketObject) > 0)
  return success()
end

--
-- Test sending an echo:
--
echoTestObj = nil
event = ""
message = ""

function testEcho()
  echoTestObj = websocket.new(ECHO_URL, function(e, m)
    event = e
    message = m
  end)
  doAfter(5, function()
    echoTestObj:send(TEST_STRING)
  end)
  return success()
end

function testEchoValues()
  if type(event) == "string" and event == "received" and type(message) == "string" and message == TEST_STRING then
    return success()
  else
    print("Waiting for echo...")
  end
end

--
-- Test the status of an open websocket:
--
openStatusTestObj = nil

function testOpenStatus()
  openStatusTestObj = websocket.new(ECHO_URL, function() end)
  return success()
end

function testOpenStatusValues()
  if openStatusTestObj:status() == "open" then
    return success()
  else
    print("Waiting for websocket to open...")
  end
end

--
-- Test the status of an closing websocket:
--
closingStatusTestObj = nil

function testClosingStatus()
  closingStatusTestObj = websocket.new(FAKE_URL, function() end)
  closingStatusTestObj:close()
  return success()
end

function testClosingStatusValues()
  if closingStatusTestObj:status() == "closing" then
    return success()
  else
    print("Waiting for websocket to start closing...")
  end
end

--
-- Test the status of an closed websocket:
--
closedStatusTestObj = nil

function testClosedStatus()
  closedStatusTestObj = websocket.new(FAKE_URL, function() end)
  return success()
end

function testClosedStatusValues()
  if closedStatusTestObj:status() == "closed" then
    return success()
  else
    print("Waiting for websocket to close...")
  end
end

--
-- Test hs.http.websocket wrapper
--

wrapperTestObj = nil
wrapperMessage = ""

function testLegacy()
  local http = require("hs.http")
  local legacy = http.websocket
  wrapperTestObj = legacy(ECHO_URL, function(m)
    wrapperMessage = m
  end)
  doAfter(5, function()
    wrapperTestObj:send(TEST_STRING)
  end)
  return success()
end

function testLegacyValues()
  if type(wrapperMessage) == "string" and wrapperMessage == TEST_STRING then
    return success()
  else
    print("Waiting for echo...")
  end
end
