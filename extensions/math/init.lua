--- === hs.math ===
---
--- Various helpful mathematical functions
---
--- This module will also mirror the contents of the built-in Lua `math` library so it is safe to do something like the following in your own code and still have access to both libraries:
---
---     local math = require("hs.math")
---     local n = math.sin(math.minFloat) -- works even though they're both from different libraries

local module = require("hs.math.internal")
local _luaMath = math

--- hs.math.isNaN(value) -> boolean
--- Function
--- Returns whether or not the value is the mathematical equivalent of "Not-A-Number"
---
--- Parameters:
---  * `value` - the value to be tested
---
--- Returns:
---  * true if `value` is equal to the mathematical "value" of NaN, or false otherwise
---
--- Notes:
---  * Mathematical `NaN` represents an impossible value, usually the result of a calculation, yet is still considered within the domain of mathematics. The most common case is the result of `n / 0` as division by 0 is considered undefined or "impossible".
---  * This function specifically checks if the `value` is `NaN` --- it does not do type checking. If `value` is not a numeric value (e.g. a string), it *cannot* be equivalent to `NaN` and this function will return false.
module.isNaN = function(x)
    return x ~= x
end

--- hs.math.isInfinite(value) -> 1, -1, false
--- Function
--- Returns whether or not the value is the mathematical equivalent of either positive or negative "Infinity"
---
--- Parameters:
---  * `value` - the value to be tested
---
--- Returns:
---  * 1 if the value is equivalent to positive infinity, -1 if the value is equivalent to negative infinity, or false otherwise.
---
--- Notes:
---  * This function specifically checks if the `value` is equivalent to positive or negative infinity --- it does not do type checking. If `value` is not a numeric value (e.g. a string), it *cannot* be equivalent to positive or negative infinity and will return false.
---  * Because lua treats any value other than `nil` and `false` as `true`, the return value of this function can be safely used in conditionals when you don't care about the sign of the infinite value.
module.isInfinite = function(x)
    return (x == math.huge) and 1 or ((x == -math.huge) and -1 or false)
end

--- hs.math.isFinite(value) -> boolean
--- Function
--- Returns whether or not the value is a finite number
---
--- Paramters:
---  * `value` - the value to be tested
---
--- Returns:
---  * true if the value is a finite number, or false otherwise
---
--- Notes:
---  * This function returns true if the value is a number and both [hs.math.isNaN](#isNaN) and [hs.math.isInfinite](#isInfinite) return false.
module.isFinite = function(value)
    return (type(value) == "number") and not (module.isNaN(value) or module.isInfinite(value))
end



--- hs.math.minFloat
--- Constant
--- Smallest positive floating point number representable in Hammerspoon
---
--- Notes:
---  * Because specifying a delay of 0 to `hs.timer.doAfter` results in the event not triggering, use this value to indicate that the action should occur as soon as possible after the current code block has completed execution.
local e = 0
while (2^(e - 1) > 0) do e = e - 1 end
local minFloat = 2^e
-- see notes at bottom for why we don't just do:
-- module.minFloat = minFloat


-- the metamethods allow `minFloat` to be a "constant" that can't be changed accidently (or purposefully)
-- this is done because `minFloat` is used internally by `coroutine.applicationYield` and we don't want to
-- inadvertantly break that expected behavior. Ok, technically since we don't set a __metatable value
-- you *could* do something like `setmetatable(package.loaded["hs.math"], nil)` and then muck with it
-- as much as you liked, but if you're that intent on screwing things up, I hate you and you deserve
-- whatever happens to you.
--
-- These also mirror `math` to support the use case described in the module documentation at the top
-- of this file.
return setmetatable(module, {
    -- only invoked if key not already in `module`
    __index = function(self, key)
        if key == "minFloat" then
            return minFloat
        else
            return _luaMath[key] or nil
        end
    end,
    __newindex = function(self, key, value)
        if key == "minFloat" then
            error("hs.math.minFloat is a constant determined at application launch and cannot be changed", 3)
        elseif _luaMath[key] then
            error(string.format("hs.math.%s mirrors lua's math.%s and cannot be changed", key, key), 3)
        else
            rawset(self, key, value)
        end
    end,
})
