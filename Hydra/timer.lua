function api.timer.seconds(n) return n end
function api.timer.minutes(n) return 60 * n end
function api.timer.hours(n)   return 60 * 60 * n end
function api.timer.days(n)    return 60 * 60 * 24 * n end
function api.timer.weeks(n)   return 60 * 60 * 24 * 7 * n end

api.doc.timer.seconds = {"api.timer.seconds(n) -> sec", "Returns the number of seconds in seconds."}
api.doc.timer.minutes = {"api.timer.minutes(n) -> sec", "Returns the number of minutes in seconds."}
api.doc.timer.hours = {"api.timer.hours(n) -> sec", "Returns the number of hours in seconds."}
api.doc.timer.days = {"api.timer.days(n) -> sec", "Returns the number of days in seconds."}
api.doc.timer.weeks = {"api.timer.weeks(n) -> sec", "Returns the number of weeks in seconds."}

api.doc.timer.timers = {"api.timer.timers = {}", "Contains all active timers; do not mutate."}
api.timer.timers = {}

api.doc.timer.new = {"api.timer.new(seconds, fn) -> timer", "Creates a new timer that can be started. Has the fields: seconds, fn."}
function api.timer.new(seconds, fn)
  return setmetatable({seconds = seconds, fn = fn}, {__index = api.timer})
end

api.doc.timer.start = {"api.timer:start(timer) -> timer", "Begins to execute timer.fn every timer.seconds; calling this does not cause an initial firing of the timer immediately."}
function api.timer:start()
  table.insert(api.timer.timers, self)
  self.__pos = # api.timer.timers
  return self:_start()
end

api.doc.timer.stop = {"api.timer:stop(timer) -> timer", "Stops the timer's fn from getting called until started again."}
function api.timer:stop()
  table.remove(api.timer.timers, self.__pos)
  return self:_stop()
end
