function api.timer.seconds(n) return n end
function api.timer.minutes(n) return 60 * n end
function api.timer.hours(n)   return 60 * 60 * n end
function api.timer.days(n)    return 60 * 60 * 24 * n end
function api.timer.weeks(n)   return 60 * 60 * 24 * 7 * n end

doc.api.timer.seconds = {"api.timer.seconds(n) -> sec", "Returns the number of seconds in seconds."}
doc.api.timer.minutes = {"api.timer.minutes(n) -> sec", "Returns the number of minutes in seconds."}
doc.api.timer.hours = {"api.timer.hours(n) -> sec", "Returns the number of hours in seconds."}
doc.api.timer.days = {"api.timer.days(n) -> sec", "Returns the number of days in seconds."}
doc.api.timer.weeks = {"api.timer.weeks(n) -> sec", "Returns the number of weeks in seconds."}

api.timer.timers = {}
api.timer.timers.n = 0

doc.api.timer.new = {"api.timer.new(seconds, fn) -> timer", "Creates a new timer that can be started. Has the fields: seconds, fn."}
function api.timer.new(seconds, fn)
  return setmetatable({seconds = seconds, fn = fn}, {__index = api.timer})
end

doc.api.timer.start = {"api.timer:start() -> timer", "Begins to execute timer.fn every timer.seconds; calling this does not cause an initial firing of the timer immediately."}
function api.timer:start()
  local id = api.timer.timers.n + 1
  api.timer.timers.n = id
  self.__id = id
  return self:_start()
end

doc.api.timer.stop = {"api.timer:stop() -> timer", "Stops the timer's fn from getting called until started again."}
function api.timer:stop()
  api.timer.timers[self.__id] = nil
  return self:_stop()
end

doc.api.timer.stopall = {"api.timer.stopall()", "Stops all running timers; called automatically when user config reloads."}
function api.timer.stopall()
  for i, t in pairs(api.timer.timers) do
    if t and i ~= "n" then t:stop() end
  end
  api.timer.timers.n = 0
end
