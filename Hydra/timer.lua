function api.timer.seconds(n) return n end
function api.timer.minutes(n) return 60 * n end
function api.timer.hours(n)   return 60 * 60 * n end
function api.timer.days(n)    return 60 * 60 * 24 * n end
function api.timer.weeks(n)   return 60 * 60 * 24 * 7 * n end

api.doc.timer.seconds = {"api.doc.timer.seconds(n) -> sec", "Returns the number of seconds in seconds."}
api.doc.timer.minutes = {"api.doc.timer.minutes(n) -> sec", "Returns the number of minutes in seconds."}
api.doc.timer.hours = {"api.doc.timer.hours(n) -> sec", "Returns the number of hours in seconds."}
api.doc.timer.days = {"api.doc.timer.days(n) -> sec", "Returns the number of days in seconds."}
api.doc.timer.weeks = {"api.doc.timer.weeks(n) -> sec", "Returns the number of weeks in seconds."}

api.timer.timers = {}

function api.timer:start()
  table.insert(api.timer.timers, self)
  self.__pos = # api.timer.timers
  return self:_start()
end

function api.timer:stop()
  table.remove(api.timer.timers, self.__pos)
  return self:_stop()
end
