--- === hs.pathwatcher ===
---
--- Watch paths recursively for changes
---
--- This simple example watches your Hammerspoon directory for changes, and when it sees a change, reloads your configs:
---
---     local myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", hs.reload):start()
---
--- This module is based primarily on code from the previous incarnation of Mjolnir.


local module = require("hs.libpathwatcher")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
