--- === hs.usb ===
---
--- Inspect USB devices

local usb = require "hs.usb.internal"
usb.watcher = require "hs.usb.watcher"

return usb
