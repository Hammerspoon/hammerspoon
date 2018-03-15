--- === hs.notdisturbmode ===
---
--- Control Not Disturb Mode
---
--- You can turn not disturb mode on / off by:
--- ```
--- local status = hs.notdisturbmode.status()
---
--- hs.notdisturbmode.on()
--- hs.notdisturbmode.off()
--- ```

local userpreference = require "hs.userpreference"
local distnotification = require "hs.distributednotifications"

local module = {}

function module.on()
  userpreference.set("dndStart", 0, "com.apple.notificationcenterui")
  userpreference.set("dndEnd", 1440, "com.apple.notificationcenterui")
  userpreference.set("doNotDisturb", true, "com.apple.notificationcenterui")
  userpreference.sync("com.apple.notificationcenterui")
  distnotification.post("com.apple.notificationcenterui.dndprefs_changed")
end

function module.off()
  userpreference.set("dndStart", nil, "com.apple.notificationcenterui")
  userpreference.set("dndEnd", nil, "com.apple.notificationcenterui")
  userpreference.set("doNotDisturb", false, "com.apple.notificationcenterui")
  userpreference.sync("com.apple.notificationcenterui")
  distnotification.post("com.apple.notificationcenterui.dndprefs_changed")
end

function module.status()
  return userpreference.get("doNotDisturb", "com.apple.notificationcenterui")
end

return module
