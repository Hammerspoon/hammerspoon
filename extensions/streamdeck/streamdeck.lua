--- === hs.streamdeck ===
---
--- Configure/control an Elgato Stream Deck.
---
--- Please note that in order for this module to work, the official Elgato Stream Deck app should not be running.
---
--- This extension supports the following devices:
---  * Stream Deck (Original)
---  * Stream Deck (Original V2)
---  * Stream Deck Plus
---  * Stream Deck Mini
---  * Stream Deck Mini (V2)
---  * Stream Deck XL
---  * Stream Deck XL (Mk2)
---  * Stream Deck Pedal
---
--- This module would not have been possible without standing on the shoulders of others:
---  * https://github.com/OpenStreamDeck/StreamDeckSharp
---  * https://github.com/Lange/node-elgato-stream-deck
---  * Hopper

-- We need these two modules for their LuaSkin Lua<->NSObject helpers
require("hs.image")
require("hs.drawing")

local USERDATA_TAG = "hs.streamdeck"
local module       = require("hs.libstreamdeck")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

-- Return Module Object --------------------------------------------------

return module
