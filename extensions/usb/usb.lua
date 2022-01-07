--- === hs.usb ===
---
--- Inspect USB devices

local usb = require "hs.libusb"
usb.watcher = require "hs.libusbwatcher"

return usb
