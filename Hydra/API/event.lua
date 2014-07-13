--- event.postkey(keycode, mods, dir = "both")
--- Posts a keyboard event. Keycode is a numeric value from `hotkey.keycodes`; dir is either 'down', 'up', or 'both'; mods is a table with any of: {'ctrl', 'alt', 'cmd', 'shift'}
--- Sometimes doesn't work inside a hotkey callback for some reason.
local dirs = {up = 1, down = 2, both = 3}
function event.postkey(mods, key, dir)
  dir = dir or "both"
  local m = {}
  for _, mod in pairs(mods) do
    m[mod:lower()] = true
  end
  event._postkey(hotkey.keycodes[key], dirs[dir], m.ctrl, m.alt, m.cmd, m.shift)
end
