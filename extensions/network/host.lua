--- === hs.network.host ===
---
--- This sub-module provides functions for acquiring host information, such as hostnames, addresses, and reachability.

local USERDATA_TAG = "hs.network.host"
local module       = require(USERDATA_TAG.."internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
