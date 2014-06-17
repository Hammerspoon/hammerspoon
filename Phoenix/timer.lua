local timer = {}
local timer_metatable = {__index = timer}

function timer.doafter(seconds, fn)
  __api.util_do_after_delay(seconds, fn)
end

function timer.newinterval(seconds, fn)
  return setmetatable({seconds = seconds, fn = fn}, timer_metatable)
end

function timer:start()
  self.__timer = __api.timer_start(self.seconds, self.fn)
end

function timer:stop()
  __api.timer_stop(self.__timer)
end

return timer
