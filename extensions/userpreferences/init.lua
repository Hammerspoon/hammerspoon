--- === hs.userpreferences ===
---
--- Interact with Preferences
---
--- You can set and get preferences like this
--- ```
--- hs.userpreferences.set("key", value, "application id here")
--- hs.userpreferences.sync()
---
--- local val = hs.userpreferences.get("key", "application id here")
--- ```

local preferences = require "hs.userpreferences.internal"
return preferences
