--- event:start()
--- Starts an event; must be in stopped state.

--- event:stop()
--- Stops an event; must be in started state.

--- event.mousemoved(fn(point)) -> event
--- Creates an event with the given callback function for when the mouse moves; doesn't start it.
function event.mousemoved(fn)
  local t = {
    callback = fn,
    start = event._mousemoved_start,
    stop = event._mousemoved_stop,
  }
  return setmetatable(t, {__gc = event._mousemoved_gc})
end
