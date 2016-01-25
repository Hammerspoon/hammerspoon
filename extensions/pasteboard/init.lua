--- === hs.pasteboard ===
---
--- Inspect/manipulate pasteboards (more commonly called clipboards). Both the system default pasteboard and custom named pasteboards can be interacted with.
---
--- This module is based partially on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.pasteboard.internal")

-- make sure the convertors for types we can recognize are loaded
require("hs.image")
require("hs.sound")
require("hs.styledtext")
require("hs.drawing.color")

return module
