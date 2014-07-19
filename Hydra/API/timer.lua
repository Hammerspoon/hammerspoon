--- timer.seconds(n) -> sec
--- Returns the number of seconds in seconds.
function timer.seconds(n) return n end

--- timer.minutes(n) -> sec
--- Returns the number of minutes in seconds.
function timer.minutes(n) return 60 * n end

--- timer.hours(n) -> sec
--- Returns the number of hours in seconds.
function timer.hours(n)   return 60 * 60 * n end

--- timer.days(n) -> sec
--- Returns the number of days in seconds.
function timer.days(n)    return 60 * 60 * 24 * n end

--- timer.weeks(n) -> sec
--- Returns the number of weeks in seconds.
function timer.weeks(n)   return 60 * 60 * 24 * 7 * n end
