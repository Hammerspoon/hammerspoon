hs.distributednotifications = require("hs.distributednotifications")

-- Storage for a notifications watcher object
distNotWatcher = nil
-- Storage for a timer callback to modify in various tests
testDistNotValue = nil

function testDistributedNotifications()
  distNotWatcher = hs.distributednotifications.new(function(name, object, userInfo)
    if (name == "org.hammerspoon.Hammerspoon.testDistributedNotifications" and
        object == "org.hammerspoon.Hammerspoon.testRunner") then
      testDistNotValue = true
    end
  end, "org.hammerspoon.Hammerspoon.testDistributedNotifications")
  distNotWatcher:start()

  hs.distributednotifications.post("org.hammerspoon.Hammerspoon.testDistributedNotifications", "org.hammerspoon.Hammerspoon.testRunner")

  return success()
end

function testDistNotValueCheck()
  if (type(testDistNotValue) == "boolean" and testDistNotValue == true) then
    return success()
  else
    return string.format("Waiting for success...(%s != true)", tostring(testDistNotValue))
  end
end
