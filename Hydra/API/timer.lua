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

timer.timers = {}
timer.timers.n = 0

--- timer.new(seconds, fn) -> timer
--- Creates a new timer that can be started. Has the fields: seconds, fn.
function timer.new(seconds, fn)
  return setmetatable({seconds = seconds, fn = fn}, {__index = timer})
end

--- timer:start() -> self
--- Begins to execute timer.fn every timer.seconds; calling this does not cause an initial firing of the timer immediately.
function timer:start()
  local id = timer.timers.n + 1
  timer.timers.n = id
  self.__id = id
  self.__rawtimer = timer._start(self.fn, self.seconds)
  return self
end

--- timer:stop() -> self
--- Stops the timer's fn from getting called until started again.
function timer:stop()
  timer.timers[self.__id] = nil
  timer._stop(self.__rawtimer)
  return self
end

--- timer.stopall()
--- Stops all running timers; called automatically when user config reloads.
function timer.stopall()
  for i, t in pairs(timer.timers) do
    if t and i ~= "n" then t:stop() end
  end
  timer.timers.n = 0
end
