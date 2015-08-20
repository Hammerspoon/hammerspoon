--- === hs.audiodevice ===
---
--- Manipulate the system's audio devices
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.audiodevice.internal")
local fnutils = require("hs.fnutils")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs.audiodevice.current([input]) -> table
--- Function
--- Fetch various metadata about the current default audio devices
---
--- Parameters:
---  * output - An optional boolean, true to fetch information about the default input device, false for output device. Defaults to false
---
--- Returns:
---  * A table with the following contents:
--- ```lua
---     {
---         name = defaultOutputDevice():name(),
---         uid = module.defaultOutputDevice():uid(),
---         muted = defaultOutputDevice():muted(),
---         volume = defaultOutputDevice():volume(),
---         device = defaultOutputDevice(),
---     }
--- ```
module.current = function(input)

    if input then
        func = module.defaultInputDevice
    else
        func = module.defaultOutputDevice
    end

    return {
        name = func():name(),
        uid = func():uid(),
        muted = func():muted(),
        volume = func():volume(),
        device = func(),
    }
end

--- hs.audiodevice.findOutputByName(name) -> device or nil
--- Function
--- Find an audio output device by name
---
--- Parameters:
---  * name - A string containing the name of an audio output device to search for
---
--- Returns:
---  * An hs.audiodevice object or nil if the device could not be found
module.findOutputByName = function(name)
    return fnutils.find(module.allOutputDevices(), function(dev) return (dev:name() == name) end)
end

--- hs.audiodevice.findInputByName(name) -> device or nil
--- Function
--- Find an audio input device by name
---
--- Parameters:
---  * name - A string containing the name of an audio input device to search for
---
--- Returns:
---  * An hs.audiodevice object or nil if the device could not be found
module.findInputByName = function(name)
return fnutils.find(module.allInputDevices(), function(dev) return (dev:name() == name) end)
end

-- Return Module Object --------------------------------------------------

return module



