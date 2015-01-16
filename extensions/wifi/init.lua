--- === hs.wifi ===
---
--- Inspect WiFi networks
--- NOTE: This extension assumes that you have one and only one WiFi interface on your Mac. If you have more than one, behaviour is undefined.

local wifi = require "hs.wifi.internal"
wifi.watcher = require "hs.wifi.watcher"

return wifi
