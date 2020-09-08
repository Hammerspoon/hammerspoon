hs.userpreferences = require("hs.userpreferences")

function testUserPreferences()
  local val = 0

  hs.userpreferences.set("test_user_preferences", 100, "com.hammerspoon.hammerspoon")
  val = hs.userpreferences.get("test_user_preferences", "com.hammerspoon.hammerspoon")
  assertIsEqual(val, 100)

  hs.userpreferences.set("test_user_preferences", false, "com.hammerspoon.hammerspoon")
  val = hs.userpreferences.get("test_user_preferences", "com.hammerspoon.hammerspoon")
  assertIsEqual(val, false)

  hs.userpreferences.set("test_user_preferences", "aaa", "com.hammerspoon.hammerspoon")
  val = hs.userpreferences.get("test_user_preferences", "com.hammerspoon.hammerspoon")
  assertIsEqual(val, "aaa")
  
  hs.userpreferences.set("test_user_preferences", nil, "com.hammerspoon.hammerspoon")
  val = hs.userpreferences.get("test_user_preferences", "com.hammerspoon.hammerspoon")
  assertIsEqual(val, nil)

  hs.userpreferences.sync("com.hammerspoon.hammerspoon")

  return success()
end
