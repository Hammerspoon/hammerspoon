--- === hs.donotdisturb ===
---
--- Control Do Not Disturb Mode
---
--- You can turn not disturb mode on / off by:
--- ```
--- local status = hs.donotdisturb.status()
---
--- hs.donotdisturb.on()
--- hs.donotdisturb.off()
--- ```

local userpreferences = require "hs.userpreferences"
local distnotification = require "hs.distributednotifications"

local module = {}

function module.on()
  userpreferences.set("dndStart", 0, "com.apple.notificationcenterui")
  userpreferences.set("dndEnd", 1440, "com.apple.notificationcenterui")
  userpreferences.set("doNotDisturb", true, "com.apple.notificationcenterui")
  userpreferences.sync("com.apple.notificationcenterui")
  distnotification.post("com.apple.notificationcenterui.dndprefs_changed")
end

function module.off()
  userpreferences.set("dndStart", nil, "com.apple.notificationcenterui")
  userpreferences.set("dndEnd", nil, "com.apple.notificationcenterui")
  userpreferences.set("doNotDisturb", false, "com.apple.notificationcenterui")
  userpreferences.sync("com.apple.notificationcenterui")
  distnotification.post("com.apple.notificationcenterui.dndprefs_changed")
end

function module.status()
  return userpreferences.get("doNotDisturb", "com.apple.notificationcenterui")
end

return module
