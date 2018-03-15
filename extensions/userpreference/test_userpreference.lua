hs.userpreference = require("hs.userpreference")

function testUserPreference()
  local val = 0

  hs.userpreference.set("test_user_preference", 100, "com.hammerspoon.hammerspoon")
  val = hs.userpreference.get("test_user_preference", "com.hammerspoon.hammerspoon")
  assertIsEqual(val, 100)

  hs.userpreference.set("test_user_preference", false, "com.hammerspoon.hammerspoon")
  val = hs.userpreference.get("test_user_preference", "com.hammerspoon.hammerspoon")
  assertIsEqual(val, false)

  hs.userpreference.set("test_user_preference", "aaa", "com.hammerspoon.hammerspoon")
  val = hs.userpreference.get("test_user_preference", "com.hammerspoon.hammerspoon")
  assertIsEqual(val, "aaa")
  
  hs.userpreference.set("test_user_preference", nil, "com.hammerspoon.hammerspoon")
  val = hs.userpreference.get("test_user_preference", "com.hammerspoon.hammerspoon")
  assertIsEqual(val, nil)

  hs.userpreference.sync("com.hammerspoon.hammerspoon")

  return success()
end
