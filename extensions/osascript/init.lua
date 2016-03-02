--- === hs.osascript ===
---
--- Execute Open Scripting Architecture (OSA) code - AppleScript and JavaScript
---

local module = require("hs.osascript.internal")

-- private variables and methods -----------------------------------------

local processResults = function(ok, result, object)
    local answer

    if not ok then
        result = result:match("^{\n(.*)}$")
        answer = {}
        local lines = hs.fnutils.split(result, ";\n")
        lines = hs.fnutils.ifilter(lines, function(line) if line ~= "" then return true end end)
        for _, line in ipairs(lines) do
            local k, v = line:match('^%s*(%w+)%s=%s(.*)$')
            v = v:match('^"(.*)"$') or v:match("^'(.*)'$") or v
            answer[k] = tonumber(v) or v
        end
    else
        answer = result:match("^<NSAppleEventDescriptor: (.*)>$")
    end
    return ok, answer, object
end

-- Public interface ------------------------------------------------------

--- hs.osascript.applescript(source) -> bool, result, object
--- Function
--- Runs AppleScript code
---
--- Parameters:
---  * source - A string containing some AppleScript code to execute
---
--- Returns:
---  * A boolean value indicating whether the code succeeded or not
---  * If the code succeeded, the output of the code string. If the code failed, a table containing an error dictionary
---  * An object containing the parsed output that can be any type, or nil if unsuccessful
---
--- Notes:
---  * Use hs.osascript._osascript(source, "AppleScript") if you always want the result as a string, even when a failure occurs
module.applescript = function(source)
    local ok, result, object = module._osascript(source, "AppleScript")
    return processResults(ok, result, object)
end


--- hs.osascript.javascript(source) -> bool, result, object
--- Function
--- Runs JavaScript code
---
--- Parameters:
---  * source - A string containing some JavaScript code to execute
---
--- Returns:
---  * A boolean value indicating whether the code succeeded or not
---  * If the code succeeded, the output of the code string. If the code failed, a table containing an error dictionary
---  * An object containing the parsed output that can be any type, or nil if unsuccessful
---
--- Notes:
---  * Use hs.osascript._osascript(source, "JavaScript") if you always want the result as a string, even when a failure occurs
module.javascript = function(source)
    local ok, result, object = module._osascript(source, "JavaScript")
    return processResults(ok, result, object)
end

setmetatable(module, { __call = function(_, ...) return module.applescript(...) end })

-- Return Module Object --------------------------------------------------

return module
