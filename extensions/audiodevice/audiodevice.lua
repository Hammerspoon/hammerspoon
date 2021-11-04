--- === hs.audiodevice ===
---
--- Manipulate the system's audio devices
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.libaudiodevice")
module.watcher = require("hs.libaudiodevicewatcher")
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
    local func
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

--- hs.audiodevice.findDeviceByName(name) -> device or nil
--- Function
--- Find an audio device by name
---
--- Parameters:
---  * name - A string containing the name of an audio device to search for
---
--- Returns:
---  * An `hs.audiodevice` object or nil if the device could not be found
module.findDeviceByName = function(name)
    return fnutils.find(module.allDevices(), function(dev) return (dev:name() == name) end)
end

--- hs.audiodevice.findDeviceByUID(uid) -> device or nil
--- Function
--- Find an audio device by UID
---
--- Parameters:
---  * uid - A string containing the UID of an audio device to search for
---
--- Returns:
---  * An `hs.audiodevice` object or nil if the device could not be found
module.findDeviceByUID = function(uid)
    return fnutils.find(module.allDevices(), function(dev) return (dev:uid() == uid) end)
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

--- hs.audiodevice.findOutputByUID(uid) -> device or nil
--- Function
--- Find an audio output device by UID
---
--- Parameters:
---  * name - A string containing the UID of an audio output device to search for
---
--- Returns:
---  * An hs.audiodevice object or nil if the device could not be found
module.findOutputByUID = function(uid)
    return fnutils.find(module.allOutputDevices(), function(dev) return (dev:uid() == uid) end)
end

--- hs.audiodevice.findInputByUID(uid) -> device or nil
--- Function
--- Find an audio input device by UID
---
--- Parameters:
---  * name - A string containing the UID of an audio input device to search for
---
--- Returns:
---  * An hs.audiodevice object or nil if the device could not be found
module.findInputByUID = function(uid)
return fnutils.find(module.allInputDevices(), function(dev) return (dev:uid() == uid) end)
end

--- hs.audiodevice.allOutputDevices() -> hs.audiodevice[]
--- Function
--- Returns a list of all connected output devices
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of zero or more audio output devices connected to the system
module.allOutputDevices = function()
return fnutils.filter(module.allDevices(), function(dev) return dev:isOutputDevice() end)
end

--- hs.audiodevice.allInputDevices() -> audio[]
--- Function
--- Returns a list of all connected input devices.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of zero or more audio input devices connected to the system
module.allInputDevices = function()
return fnutils.filter(module.allDevices(), function(dev) return dev:isInputDevice() end)
end

--- === hs.audiodevice.datasource ===
---
--- Inspect/manipulate the data sources of an audio device
---
--- Note: These objects are obtained from the methods on an `hs.audiodevice` object

-- Return Module Object --------------------------------------------------

return module
