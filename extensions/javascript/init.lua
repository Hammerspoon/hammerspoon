--- === hs.javascript ===
---
--- Execute JavaScript code
---
--- This module is based on hs.applescript and uses OSAKit

local module = require("hs.javascript.internal")

-- private variables and methods -----------------------------------------

local split = function(div,str)
    if (div=='') then return { str } end
    local pos,arr = 0,{}
    for st,sp in function() return string.find(str,div,pos) end do
        table.insert(arr,string.sub(str,pos,st-1))
        pos = sp + 1
    end
    if string.sub(str,pos) ~= "" then
        table.insert(arr,string.sub(str,pos))
    end
    return arr
end

-- Public interface ------------------------------------------------------

--- hs.javascript.javascript(string) -> bool, result
--- Function
--- Runs JavaScript code
---
--- Parameters:
---  * string - Some JavaScript code to execute
---
--- Returns:
---  * A boolean value indicating whether the code succeeded or not
---  * If the code succeeded, the output of the code string. If the code failed, a table containing an error dictionary
---
--- Notes:
---  * Use hs.javascript._javascript(string) if you always want the result as a string, even when a failure occurs.
module.javascript = function(command)
    local ok, result = module._javascript(command)
    local answer

    if not ok then
        result = result:match("^{\n(.*)}$")
        answer = {}
        local lines = split(";\n", result)
        for _, line in ipairs(lines) do
            local k, v = line:match('^%s*(%w+)%s=%s(.*)$')
            v = v:match('^"(.*)"$') or v:match("^'(.*)'$") or v
            answer[k] = tonumber(v) or v
        end
    else
        result = result:match("^<NSAppleEventDescriptor: (.*)>$")
        if tonumber(result) then
            answer = tonumber(result)
        elseif result:match("^'utxt'%(.*%)$") then
            result = result:match("^'utxt'%((.*)%)$")
            answer = result:match('^"(.*)"$') or result:match("^'(.*)'$") or result
        else
            answer = result
        end
    end
    return ok, answer
end

setmetatable(module, { __call = function(_, ...) return module.javascript(...) end })

-- Return Module Object --------------------------------------------------

return module

-- collection of return types I need to catch, and then maybe time to recursively parse through 'obj' results
--
-- > hs.javascript("")
-- true	null()
-- > hs.javascript("true")
-- true	'true'
-- > hs.javascript("false")
-- true	'false'

