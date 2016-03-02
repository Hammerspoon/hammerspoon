--- === hs.osascript ===
---
--- Execute Open Scripting Architecture (OSA) code - AppleScript and JavaScript
---

local module = require("hs.osascript.internal")

-- private variables and methods -----------------------------------------

local processResults = function(ok, object, rawDescriptor)
    local descriptor

    if not ok then
        rawDescriptor = rawDescriptor:match("^{\n(.*)}$")
        descriptor = {}
        local lines = hs.fnutils.split(rawDescriptor, ";\n")
        lines = hs.fnutils.ifilter(lines, function(line) if line ~= "" then return true end end)
        for _, line in ipairs(lines) do
            local k, v = line:match('^%s*(%w+)%s=%s(.*)$')
            v = v:match('^"(.*)"$') or v:match("^'(.*)'$") or v
            descriptor[k] = tonumber(v) or v
        end
    else
        descriptor = rawDescriptor:match("^<NSAppleEventDescriptor: (.*)>$")
    end
    return ok, object, descriptor
end

-- Public interface ------------------------------------------------------

--- hs.osascript.applescript(source) -> bool, object, descriptor
--- Function
--- Runs AppleScript code
---
--- Parameters:
---  * source - A string containing some AppleScript code to execute
---
--- Returns:
---  * A boolean value indicating whether the code succeeded or not
---  * An object containing the parsed output that can be any type, or nil if unsuccessful
---  * If the code succeeded, the raw output of the code string. If the code failed, a table containing an error dictionary
---
--- Notes:
---  * Use hs.osascript._osascript(source, "AppleScript") if you always want the result as a string, even when a failure occurs
module.applescript = function(source)
    local ok, object, descriptor = module._osascript(source, "AppleScript")
    return processResults(ok, object, descriptor)
end


--- hs.osascript.javascript(source) -> bool, object, descriptor
--- Function
--- Runs JavaScript code
---
--- Parameters:
---  * source - A string containing some JavaScript code to execute
---
--- Returns:
---  * A boolean value indicating whether the code succeeded or not
---  * An object containing the parsed output that can be any type, or nil if unsuccessful
---  * If the code succeeded, the raw output of the code string. If the code failed, a table containing an error dictionary
---
--- Notes:
---  * Use hs.osascript._osascript(source, "JavaScript") if you always want the result as a string, even when a failure occurs
module.javascript = function(source)
    local ok, object, descriptor = module._osascript(source, "JavaScript")
    return processResults(ok, object, descriptor)
end

setmetatable(module, { __call = function(_, ...) return module.applescript(...) end })

-- Return Module Object --------------------------------------------------

return module
