--- === hs.userpreference ===
---
--- Interact with Preferences
---
--- You can set and get preference like this
--- ```
--- hs.userpreference.set("key", value, "application id here")
--- hs.userpreference.sync()
---
--- local val = hs.userpreference.get("key", "application id here")
--- ```

local preference = require "hs.userpreference.internal"
return preference
