--- === hs.audiodevice ===
---
--- Manipulate the system's audio devices.
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.audiodevice.internal")
local fnutils = require("hs.fnutils")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs.audiodevice.current() -> table
--- Function
--- Convenience function which returns a table with the following keys and values:
--- ~~~lua
---     {
---         name = defaultOutputDevice():name(),
---         uid = module.defaultOutputDevice():uid(),
---         muted = defaultOutputDevice():muted(),
---         volume = defaultOutputDevice():volume(),
---         device = defaultOutputDevice(),
---     }
--- ~~~
module.current = function()
    return {
        name = module.defaultOutputDevice():name(),
        uid = module.defaultOutputDevice():uid(),
        muted = module.defaultOutputDevice():muted(),
        volume = module.defaultOutputDevice():volume(),
        device = module.defaultOutputDevice(),
    }
end

--- hs.audiodevice.findOutputByName(name) -> device or nil
--- Function
--- Convenience function which returns an audiodevice based on its name, or nil if it can't be found
module.findOutputByName = function(name)
    return fnutils.find(module.allOutputDevices(), function(dev) return (dev:name() == name) end)
end

-- Return Module Object --------------------------------------------------

return module



