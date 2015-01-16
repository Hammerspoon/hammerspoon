--- === hs.timer ===
---
--- Execute functions with various timing rules
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.timer.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs.timer.seconds(n) -> sec
--- Returns the number of seconds in seconds.
function module.seconds(n) return n end

--- hs.timer.minutes(n) -> sec
--- Returns the number of minutes in seconds.
function module.minutes(n) return 60 * n end

--- hs.timer.hours(n) -> sec
--- Returns the number of hours in seconds.
function module.hours(n)   return 60 * 60 * n end

--- hs.timer.days(n) -> sec
--- Returns the number of days in seconds.
function module.days(n)    return 60 * 60 * 24 * n end

--- hs.timer.weeks(n) -> sec
--- Returns the number of weeks in seconds.
function module.weeks(n)   return 60 * 60 * 24 * 7 * n end

-- Return Module Object --------------------------------------------------

return module
