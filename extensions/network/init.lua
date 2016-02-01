--- === hs.network ===
---
--- This module provides functions for inquiring about and monitoring changes to the network.

local USERDATA_TAG   = "hs.network"
local module         = {}
module.reachability  = require(USERDATA_TAG..".reachability")
module.host          = require(USERDATA_TAG..".host")
module.configuration = require(USERDATA_TAG..".configuration")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
