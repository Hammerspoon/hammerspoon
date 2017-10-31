--- === hs.midi ===
---
--- MIDI Control for Hammerspoon.
---
--- This extension makes use of [MIKMIDI](https://github.com/mixedinkey-opensource/MIKMIDI), an easy-to-use Objective-C MIDI library created by Andrew Madsen and developed by him and Chris Flesner of [Mixed In Key](http://www.mixedinkey.com/).

local USERDATA_TAG = "hs.midi"
local module       = require(USERDATA_TAG..".internal")

-- Private Variables & Methods -----------------------------------------

-- Public Interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
