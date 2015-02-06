--- === hs.timer ===
---
--- Execute functions with various timing rules
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.timer.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

function module.seconds(n) return n end

--- hs.timer.minutes(n) -> seconds
--- Function
--- Converts minutes to seconds
---
--- Parameters:
---  * n - A number of minutes
---
--- Returns:
---  * The number of seconds in n minutes
function module.minutes(n) return 60 * n end

--- hs.timer.hours(n) -> seconds
--- Function
--- Converts hours to seconds
---
--- Parameters:
---  * n - A number of hours
---
--- Returns:
---  * The number of seconds in n hours
function module.hours(n)   return 60 * 60 * n end

--- hs.timer.days(n) -> sec
--- Function
--- Converts days to seconds
---
--- Parameters:
---  * n - A number of days
---
--- Returns:
---  * The number of seconds in n days
function module.days(n)    return 60 * 60 * 24 * n end

--- hs.timer.weeks(n) -> sec
--- Function
--- Converts weeks to seconds
---
--- Parameters:
---  * n - A number of weeks
---
--- Returns:
---  * The number of seconds in n weeks
function module.weeks(n)   return 60 * 60 * 24 * 7 * n end

-- Return Module Object --------------------------------------------------

return module
