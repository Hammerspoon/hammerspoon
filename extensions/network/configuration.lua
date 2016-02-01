--- === hs.network.configuration ===
---
--- This sub-module provides access to the current location set configuration settings in the system's dynamic store.

local USERDATA_TAG  = "hs.network.configuration"
local module        = require(USERDATA_TAG.."internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
