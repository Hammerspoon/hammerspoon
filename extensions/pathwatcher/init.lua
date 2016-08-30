--- === hs.pathwatcher ===
---
--- Watch paths recursively for changes
---
--- This simple example watches your Hammerspoon directory for changes, and when it sees a change, reloads your configs:
---
---     local myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", hs.reload):start()
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).


local module = require("hs.pathwatcher.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
