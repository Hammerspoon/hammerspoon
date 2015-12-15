--- === hs.wifi ===
---
--- Inspect WiFi networks

local wifi = require "hs.wifi.internal"
wifi.watcher = require "hs.wifi.watcher"
local log    = require("hs.logger").new("hs.wifi","warning")
wifi.log = log
wifi._registerLogForC(log)
wifi._registerLogForC = nil

return wifi
