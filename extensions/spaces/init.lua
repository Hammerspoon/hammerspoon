--- === hs.spaces ===
---
--- This module provides the functionality, as it was in Hydra and Mjolnir, for `spaces`.
---
--- These functions utilize private API's within the OS X internals, and are known to have unpredictable behavior under Mavericks and Yosemite when "Displays have separate Spaces" is checked under the Mission Control system preferences.
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.spaces.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module



