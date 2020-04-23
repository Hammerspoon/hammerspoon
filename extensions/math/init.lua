--- === hs.math ===
---
--- Various helpful mathematical functions

local module = require("hs.math.internal")

--- hs.math.minFloat
--- Constant
--- Smallest positive floating point number representable in Hammerspoon
---
--- Notes:
---  * Because specifying a delay of 0 to `hs.timer.doAfter` results in the event not triggering, use this value to indicate that the action should occur as soon as possible after the current code block has completed execution.
local e = 0
while (2^(e - 1) > 0) do e = e - 1 end
local minFloat = 2^e

return setmetatable(module, {
    -- only invoked if key not already in `module`
    __index = function(self, key)
        if key == "minFloat" then
            return minFloat
        else
            return nil
        end
    end,
})
