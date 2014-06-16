local mouse = {}

local function restore(m)
  __api.mouse_set(m.x, m.y)
end

function mouse.capture()
  local m = {}
  m.x, m.y = __api.mouse_get()
  m.restore = restore
  return m
end

return mouse
