--- === hs.crash ===
---
--- Various features/facilities for developers who are working on Hammerspoon itself, or writing extensions for it. It is extremely unlikely that you should need any part of this extension, in a normal user configuration.

local crash = require "hs.crash.internal"

--- hs.crash.crashLogToNSLog
--- Variable
--- A boolean value of true will log Hammerspoon's crash log with NSLog, false will silently capture messages in case of a crash. Defaults to false.
crash.crashLogToNSLog = false

crash.crashLog = function(message)
    crash._crashLog(message, crash.crashLogToNSLog)
end

return crash
