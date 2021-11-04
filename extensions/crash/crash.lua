--- === hs.crash ===
---
--- Various features/facilities for developers who are working on Hammerspoon itself, or writing extensions for it. It is extremely unlikely that you should need any part of this extension, in a normal user configuration.

local crash = require "hs.libcrash"

--- hs.crash.dumpCLIBS() -> table
--- Function
--- Dumps the contents of Lua's CLIBS registry
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing all the paths of C libraries that have been loaded into the Lua runtime
---
--- Notes:
---  * This is probably only useful to extension developers as a useful way of ensuring that you are loading C libraries from the places you expect.
crash.dumpCLIBS = function()
    local CLIBS = {}
    local tmpclibs

    for k,v in pairs(debug.getregistry()) do
        if type(k) == "userdata" and type(v) == "table" then
            tmpclibs = v
        end
    end

    if tmpclibs then
        for k,_ in pairs(tmpclibs) do
            if type(k) == "string" then
                table.insert(CLIBS, k)
            end
        end
    end

    return CLIBS
end

--- hs.crash.attemptMemoryRelease()
--- Function
--- Attempts to reduce RAM usage of Hammerspoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * This function will print some memory usage numbers (in bytes) to the Hammerspoon Console before and after forcing Lua's garbage collector
crash.attemptMemoryRelease = function()
    print("Process resident size: "..crash.residentSize())
    print("Lua state size: "..math.floor(collectgarbage("count")*1024))

    collectgarbage()

    print("Process resident size: "..crash.residentSize())
    print("Lua state size: "..math.floor(collectgarbage("count")*1024))
end

return crash
