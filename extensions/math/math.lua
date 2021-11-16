--- === hs.math ===
---
--- Various helpful mathematical functions
---
--- This module includes, and is a superset of the built-in Lua `math` library so it is safe to do something like the following in your own code and still have access to both libraries:
---
---     local math = require("hs.math")
---     local n = math.sin(math.minFloat) -- works even though they're both from different libraries
---
--- The documentation for the math library can be found at http://www.lua.org/manual/5.3/ or from the Hammerspoon console via the help command: `help.lua.math`. This includes the following functions and variables:
---
---   * hs.math.abs        - help available via `help.lua.math.abs`
---   * hs.math.acos       - help available via `help.lua.math.acos`
---   * hs.math.asin       - help available via `help.lua.math.asin`
---   * hs.math.atan       - help available via `help.lua.math.atan`
---   * hs.math.ceil       - help available via `help.lua.math.ceil`
---   * hs.math.cos        - help available via `help.lua.math.cos`
---   * hs.math.deg        - help available via `help.lua.math.deg`
---   * hs.math.exp        - help available via `help.lua.math.exp`
---   * hs.math.floor      - help available via `help.lua.math.floor`
---   * hs.math.fmod       - help available via `help.lua.math.fmod`
---   * hs.math.huge       - help available via `help.lua.math.huge`
---   * hs.math.log        - help available via `help.lua.math.log`
---   * hs.math.max        - help available via `help.lua.math.max`
---   * hs.math.maxinteger - help available via `help.lua.math.maxinteger`
---   * hs.math.min        - help available via `help.lua.math.min`
---   * hs.math.mininteger - help available via `help.lua.math.mininteger`
---   * hs.math.modf       - help available via `help.lua.math.modf`
---   * hs.math.pi         - help available via `help.lua.math.pi`
---   * hs.math.rad        - help available via `help.lua.math.rad`
---   * hs.math.random     - help available via `help.lua.math.random`
---   * hs.math.randomseed - help available via `help.lua.math.randomseed`
---   * hs.math.sin        - help available via `help.lua.math.sin`
---   * hs.math.sqrt       - help available via `help.lua.math.sqrt`
---   * hs.math.tan        - help available via `help.lua.math.tan`
---   * hs.math.tointeger  - help available via `help.lua.math.tointeger`
---   * hs.math.type       - help available via `help.lua.math.type`
---   * hs.math.ult        - help available via `help.lua.math.ult`
---
--- Additional functions and values that are specific to Hammerspoon which provide expanded math support are documented here.
local module = require("hs.libmath")
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
--- Parameters:
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
