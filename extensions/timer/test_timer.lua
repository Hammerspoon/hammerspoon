hs.timer = require("hs.timer")

-- Storage for a timer object in various tests
testTimer = nil
-- Storage for a timer callback to modify in various tests
testTimerValue = nil

function testWeeks()
  assertIsEqual(86400*7, hs.timer.weeks(1))
  return success()
end

function testDays()
  assertIsEqual(86400, hs.timer.days(1))
  assertIsEqual(86400*2, hs.timer.days(2))
  return success()
end

function testHours()
  assertIsEqual(3600, hs.timer.hours(1))
  assertIsEqual(3600*2, hs.timer.hours(2))
  return success()
end

function testMinutes()
  assertIsEqual(60, hs.timer.minutes(1))
  assertIsEqual(60*2, hs.timer.minutes(2))
  return success()
end

-- timeOrDuration - a string that can have any of the following formats:
--"HH:MM:SS" or "HH:MM" - represents a time of day (24-hour clock), returns the number of seconds since midnight
--"DDdHHh", "HHhMMm", "MMmSSs", "DDd", "HHh", "MMm", "SSs", "NNNNms" - represents a duration in days, hours, minutes, seconds and/or milliseconds

function testSeconds()
  assertIsEqual(43200, hs.timer.seconds("12:00:00"))
  assertIsEqual(64800, hs.timer.seconds("18:00"))
  assertIsEqual(86400*1.5, hs.timer.seconds("1d12h"))
  assertIsEqual(60*60*1.5, hs.timer.seconds("1h30m"))
  assertIsEqual(86400*2, hs.timer.seconds("2d"))
  assertIsEqual(60*2, hs.timer.seconds("2m"))
  assertIsEqual(45, hs.timer.seconds("45s"))
  assertIsEqual(1/1000, hs.timer.seconds("1ms"))

  return success()
end

function testLocalTime()
  local localTime = hs.timer.localTime()
  local luaTime = os.date('*t')
  assertIsNumber(localTime)
  assertIsEqual((luaTime.sec + luaTime.min*60 + luaTime.hour*3600), localTime)

  return success()
end

function testSecondsSinceEpoch()
  local luaTime = os.time()
  local hsTime = hs.timer.secondsSinceEpoch()
  local fuzz = hsTime - luaTime

  -- Since we have no objective way of getting the time with zero time lag, we'll just compare the Lua epoch time and the Hammerspoon epoch time and ensure that their offset is small
  assertGreaterThan(-5, fuzz)
  assertLessThan(5, fuzz)

  return success()
end

function testUsleep()
  local beforeTime = os.time()
  hs.timer.usleep(5000000)
  local afterTime = os.time()

  assertGreaterThan(beforeTime, afterTime)
  assertGreaterThanOrEqualTo(4, afterTime - beforeTime)
  assertLessThanOrEqualTo(6, afterTime - beforeTime)

  return success()
end

function testTimerValueCheck()
  if (type(testTimerValue) == "boolean" and testTimerValue == true) then
    return success()
  else
    return string.format("Waiting for success...(%s != true)", tostring(testTimerValue))
  end
end

function testDoAfterStart()
  assertIsNil(testTimerValue)
  testTimerValue = false

  testTimer = hs.timer.doAfter(3, function() testTimerValue = true end)
  assertIsUserdataOfType("hs.timer", testTimer)
  assertTrue(testTimer:running())

  return success()
end

function testDoAtStart()
  assertIsNil(testTimerValue)
  testTimerValue = false

  testTimer = hs.timer.doAt(hs.timer.localTime() + 2, function() print("HELLO") ; testTimerValue = true end)
  assertIsUserdataOfType("hs.timer", testTimer)
  assertTrue(testTimer:running())

  return success()
end

function testDoEveryStart()
  assertIsNil(testTimerValue)
  testTimerValue = 0

  testTimer = hs.timer.doEvery(1, function()
                                    assertIsEqual("number", type(testTimerValue))
                                    if type(testTimerValue) == "number" then
                                      if testTimerValue > 2 then
                                        print("..reached testTimerValue threshold")
                                        testTimerValue = true
                                      else
                                        print("..incrementing testTimerValue")
                                        testTimerValue = testTimerValue + 1
                                      end
                                    end
                                  end)
  assertIsUserdataOfType("hs.timer", testTimer)
  assertTrue(testTimer:running())

  return success()
end

function testDoUntilStart()
  assertIsNil(testTimerValue)
  testTimerValue = 0

  testTimer = hs.timer.doUntil(function()
                                 if testTimerValue > 2 then
                                   testTimerValue = true
                                   return true
                                 else
                                   return false
                                 end
                               end, function() testTimerValue = testTimerValue + 1 end)
  assertIsUserdataOfType("hs.timer", testTimer)
  assertTrue(testTimer:running())

  return success()
end

function testDoWhileStart()
  assertIsNil(testTimerValue)
  testTimerValue = 0

  testTimer = hs.timer.doWhile(function()
                                 if testTimerValue < 3 then
                                   testTimerValue = testTimerValue + 1
                                   return true
                                 else
                                   testTimerValue = true
                                   return false
                                 end
                               end, function() testTimerValue = testTimerValue + 1 end)
  assertIsUserdataOfType("hs.timer", testTimer)
  assertTrue(testTimer:running())

  return success()
end

function testWaitUntilStart()
  assertIsNil(testTimerValue)
  testTimerValue = 0

  testTimer = hs.timer.waitUntil(function()
                                   if testTimerValue > 2 then
                                     return true
                                   else
                                     testTimerValue = testTimerValue + 1
                                     return false
                                   end
                                 end, function() testTimerValue = true end)
  assertIsUserdataOfType("hs.timer", testTimer)
  assertTrue(testTimer:running())

  return success()
end

function testWaitWhileStart()
  assertIsNil(testTimerValue)
  testTimerValue = 0

  testTimer = hs.timer.waitWhile(function()
                                   if testTimerValue < 2 then
                                     testTimerValue = testTimerValue + 1
                                     return true
                                   else
                                     return false
                                   end
                                 end, function() testTimerValue = true end)
  assertIsUserdataOfType("hs.timer", testTimer)
  assertTrue(testTimer:running())

  return success()
end

function testNew()
  local timer = hs.timer.new(2, function() end)
  assertIsUserdataOfType("hs.timer", timer)
  return success()
end

function testToString()
  assertIsString(tostring(hs.timer.new(1, function() end)))
  assertIsString(tostring(hs.timer.new(1, function() end):start()))
  assertIsString(tostring(hs.timer.new(1, function() end):start():stop()))
  assertIsString(tostring(hs.timer.doAfter(1, function() end):stop()))
  return success()
end

function testRunningAndStartStop()
  local timer = hs.timer.new(1, function() end)
  assertIsUserdataOfType("hs.timer", timer)
  assertFalse(timer:running())
  timer:start()
  assertTrue(timer:running())
  timer:stop()
  assertFalse(timer:running())

  return success()
end

function testTriggers()
  local timer = hs.timer.new(10, function() print("THIS SHOULD NEVER PRINT") assertFalse(True) end)
  assertIsUserdataOfType("hs.timer", timer)
  assertFalse(timer:running())
  timer:start()
  assertGreaterThan(8, timer:nextTrigger())
  assertLessThanOrEqualTo(10, timer:nextTrigger())
  timer:setNextTrigger(100)
  assertGreaterThan(98, timer:nextTrigger())
  assertLessThanOrEqualTo(100, timer:nextTrigger())

  return success()
end

function testNeverStart()
  -- This test ensures that a timer doesn't automatically start running without being :start()ed
  testTimerValue = False
  testTimer = hs.timer.new(1, function() testTimerValue = true end)

  return success()
end

function testImmediateFireStart()
  testTimer = hs.timer.new(1000, function() testTimerValue = true end)
  testTimer:start()
  testTimer:fire()

  return success()
end
