local websocket         = require "hs.websocket"
local timer             = require "hs.timer"

local doAfter           = timer.doAfter

--
-- Variables:
--
local TEST_STRING       = "ABC123"
local ECHO_URL          = "wss://echo.websocket.org/"
local FAKE_URL          = "wss://fake.com/"

--
-- Test creating a new object:
--
function testNew()
  local websocketObject = websocket.new(ECHO_URL, function() end)
  assertIsUserdataOfType("hs.websocket", websocketObject)
  assertTrue(#tostring(websocketObject) > 0)
  websocketObject:close()
  return success()
end

--
-- Test sending an echo:
--
local echoTestObj = nil
local event = ""
local message = ""

function testEcho()
  echoTestObj = websocket.new(ECHO_URL, function(e, m)
    event = e
    message = m
  end)
  doAfter(5, function()
    echoTestObj:send(TEST_STRING)
    echoTestObj:close()
  end)
  return success()
end

function testEchoValues()
  if type(event) == "string" and event == "received" and type(message) == "string" and message == TEST_STRING then
    return success()
  else
    return "Waiting for echo..."..echoTestObj:status()
  end
end

--
-- Test the status of an open websocket:
--
local openStatusTestObj = nil

function testOpenStatus()
  openStatusTestObj = websocket.new(ECHO_URL, function() end)
  return success()
end

function testOpenStatusValues()
  if openStatusTestObj:status() == "open" then
    openStatusTestObj:close()
    return success()
  else
    return "Waiting for websocket to open..."..openStatusTestObj:status()
  end
end

--
-- Test the status of an closing websocket:
--
local closingStatusTestObj = nil

function testClosingStatus()
  closingStatusTestObj = websocket.new(FAKE_URL, function() end)
  closingStatusTestObj:close()
  return success()
end

function testClosingStatusValues()
  if closingStatusTestObj:status() == "closing" then
    return success()
  else
    return "Waiting for websocket to start closing..."..closingStatusTestObj:status()
  end
end

--
-- Test the status of an closed websocket:
--
local closedStatusTestObj = nil

function testClosedStatus()
  closedStatusTestObj = websocket.new(FAKE_URL, function() end)
  return success()
end

function testClosedStatusValues()
  if closedStatusTestObj:status() == "closed" then
    return success()
  else
    return "Waiting for websocket to close..."..closedStatusTestObj:status()
  end
end

--
-- Test hs.http.websocket wrapper
--

local wrapperTestObj = nil
local wrapperMessage = ""

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
    wrapperTestObj:close()
    return success()
  else
    return "Waiting for echo..."..wrapperTestObj:status()
  end
end
