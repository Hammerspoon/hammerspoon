function api.timer.seconds(n) return n end
function api.timer.minutes(n) return 60 * n end
function api.timer.hours(n)   return 60 * 60 * n end
function api.timer.days(n)    return 60 * 60 * 24 * n end
function api.timer.weeks(n)   return 60 * 60 * 24 * 7 * n end

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
