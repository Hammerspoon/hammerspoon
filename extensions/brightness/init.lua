--- === hs.brightness ===
---
--- Inspect/manipulate display brightness
---
--- Home: https://github.com/asmagill/mjolnir_asm.sys
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

-- try to load private framework for brightness controls
local state, msg = package.loadlib(
    "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/Current/DisplayServices",
    "*"
)
if not state then
    hs.printf("-- unable to load DisplayServices framework; may impact brightness control: %s", msg)
end

local module = require("hs.brightness.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module



