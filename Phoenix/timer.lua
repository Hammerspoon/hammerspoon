local timer = {}

function timer.doafter(seconds, fn)
  __api.util_do_after_delay(seconds, fn)
end

return timer
