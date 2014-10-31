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
---         name = defaultoutputdevice():name(),
---         uid = module.defaultoutputdevice():uid(),
---         muted = defaultoutputdevice():muted(),
---         volume = defaultoutputdevice():volume(),
---         device = defaultoutputdevice(),
---     }
--- ~~~
module.current = function()
    return {
        name = module.defaultoutputdevice():name(),
        uid = module.defaultoutputdevice():uid(),
        muted = module.defaultoutputdevice():muted(),
        volume = module.defaultoutputdevice():volume(),
        device = module.defaultoutputdevice(),
    }
end

--- hs.audiodevice.findoutputbyname(name) -> device or nil
--- Function
--- Convenience function which returns an audiodevice based on its name, or nil if it can't be found
module.findoutputbyname = function(name)
    return fnutils.find(module.alloutputdevices(), function(dev) return (dev:name() == name) end)
end

-- Return Module Object --------------------------------------------------

return module



