--- === hs.json ===
---
--- This module provides JSON encoding and decoding for Mjolnir utilizing the NSJSONSerialization functions available in OS X 10.7 +
---
--- This module is based partially on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).
---

local module = require("hs.json.internal-json")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
