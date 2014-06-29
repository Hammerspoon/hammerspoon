function timer.seconds(n) return n end
function timer.minutes(n) return 60 * n end
function timer.hours(n)   return 60 * 60 * n end
function timer.days(n)    return 60 * 60 * 24 * n end
function timer.weeks(n)   return 60 * 60 * 24 * 7 * n end

doc.timer.seconds = {"timer.seconds(n) -> sec", "Returns the number of seconds in seconds."}
doc.timer.minutes = {"timer.minutes(n) -> sec", "Returns the number of minutes in seconds."}
doc.timer.hours = {"timer.hours(n) -> sec", "Returns the number of hours in seconds."}
doc.timer.days = {"timer.days(n) -> sec", "Returns the number of days in seconds."}
doc.timer.weeks = {"timer.weeks(n) -> sec", "Returns the number of weeks in seconds."}

timer.timers = {}
timer.timers.n = 0

doc.timer.new = {"timer.new(seconds, fn) -> timer", "Creates a new timer that can be started. Has the fields: seconds, fn."}
function timer.new(seconds, fn)
  return setmetatable({seconds = seconds, fn = fn}, {__index = timer})
end

doc.timer.start = {"timer:start() -> timer", "Begins to execute timer.fn every timer.seconds; calling this does not cause an initial firing of the timer immediately."}
function timer:start()
  local id = timer.timers.n + 1
  timer.timers.n = id
  self.__id = id
  return self:_start()
end

doc.timer.stop = {"timer:stop() -> timer", "Stops the timer's fn from getting called until started again."}
function timer:stop()
  timer.timers[self.__id] = nil
  return self:_stop()
end

doc.timer.stopall = {"timer.stopall()", "Stops all running timers; called automatically when user config reloads."}
function timer.stopall()
  for i, t in pairs(timer.timers) do
    if t and i ~= "n" then t:stop() end
  end
  timer.timers.n = 0
end
