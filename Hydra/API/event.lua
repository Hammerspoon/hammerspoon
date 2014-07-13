--- event.postkey(keycode, mods, dir = "both")
--- Posts a keyboard event.
---   keycode is a numeric value from `hotkey.keycodes`
---   dir is either 'press', 'release', or 'pressrelease'
---   mods is a table with any of: {'ctrl', 'alt', 'cmd', 'shift'}
--- Sometimes this doesn't work inside a hotkey callback for some reason.
local dirs = {press = 1, release = 2, pressrelease = 3}
function event.postkey(mods, key, dir)
  dir = dir or "pressrelease"
  local m = {}
  for _, mod in pairs(mods) do
    m[mod:lower()] = true
  end
  event._postkey(hotkey.keycodes[key], dirs[dir], m.ctrl, m.alt, m.cmd, m.shift)
end
