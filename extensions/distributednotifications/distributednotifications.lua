--- === hs.distributednotifications ===
---
--- Interact with NSDistributedNotificationCenter
--- There are many notifications posted by parts of OS X, and third party apps, which may be interesting to react to using this module.
---
--- You can discover the notifications that are being posted on your system with some code like this:
--- ```
--- foo = hs.distributednotifications.new(function(name, object, userInfo) print(string.format("name: %s\nobject: %s\nuserInfo: %s\n", name, object, hs.inspect(userInfo))) end)
--- foo:start()
--- ```
---
--- Note that distributed notifications are expensive - they involve lots of IPC. Also note that they are not guaranteed to be delivered, particularly if the system is very busy.

local distributednotifications = require "hs.libdistributednotifications"
return distributednotifications
