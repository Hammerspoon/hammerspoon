--- === hs.osascript ===
---
--- Execute Open Scripting Architecture (OSA) code - AppleScript and JavaScript
---

local module = require("hs.libosascript")
local fnutils = require("hs.fnutils")

-- private variables and methods -----------------------------------------

local processResults = function(ok, object, rawDescriptor)
    local descriptor

    if not ok then
        rawDescriptor = rawDescriptor:match("^{\n(.*)}$")
        descriptor = {}
        local lines = fnutils.split(rawDescriptor, ";\n")
        lines = fnutils.ifilter(lines, function(line) return line ~= "" end)
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

-- Reads the contents of a file found at fileName and returns the contents as a string.
-- Will throw an error if the specified file can not be read.
-- Filters out a shebang if it's present
local importScriptFile = function(fileName)
    local f = io.open(fileName, "rb")
    if not f then
        error("Can't read file " .. fileName)
    end
    local content = f:read("*all")
    f:close()
    content = string.gsub(content, "^#![^\n]*\n", "")
    return content
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

--- hs.osascript.applescriptFromFile(fileName) -> bool, object, descriptor
--- Function
--- Runs AppleScript code from a source file.
---
--- Parameters:
---  * fileName - A string containing the file name of an AppleScript file to execute.
---
--- Returns:
---  * A boolean value indicating whether the code succeeded or not
---  * An object containing the parsed output that can be any type, or nil if unsuccessful
---  * If the code succeeded, the raw output of the code string. If the code failed, a table containing an error dictionary
---
--- Notes:
---  * This function uses hs.osascript.applescript for execution.
---  * Use hs.osascript._osascript(source, "AppleScript") if you always want the result as a string, even when a failure occurs. However, this function can only take a string, and not a file name.
module.applescriptFromFile = function(fileName)
    local source = importScriptFile(fileName)
    return module.applescript(source)
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

--- hs.osascript.javascriptFromFile(fileName) -> bool, object, descriptor
--- Function
--- Runs JavaScript code from a source file.
---
--- Parameters:
---  * fileName - A string containing the file name of an JavaScript file to execute.
---
--- Returns:
---  * A boolean value indicating whether the code succeeded or not
---  * An object containing the parsed output that can be any type, or nil if unsuccessful
---  * If the code succeeded, the raw output of the code string. If the code failed, a table containing an error dictionary
---
--- Notes:
---  * This function uses hs.osascript.javascript for execution.
---  * Use hs.osascript._osascript(source, "JavaScript") if you always want the result as a string, even when a failure occurs. However, this function can only take a string, and not a file name.
module.javascriptFromFile = function(fileName)
    local source = importScriptFile(fileName)
    return module.javascript(source)
end

setmetatable(module, { __call = function(_, ...) return module.applescript(...) end })

-- Return Module Object --------------------------------------------------

return module
