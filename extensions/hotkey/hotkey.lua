--- === hs.hotkey ===
---
--- Create and manage global hotkeys.

local hotkey = require "hs.hotkey.internal"
local keycodes = require "hs.keycodes"

--- hs.hotkey.new(mods, key, pressedfn, releasedfn = nil) -> hotkey
--- Constructor
--- Creates a new hotkey that can be enabled.
---
--- The `mods` parameter is case-insensitive and may contain any of the following strings: "cmd", "ctrl", "alt", or "shift".
---
--- The `key` parameter is case-insensitive and may be any string value found in hs.keycodes.map
---
--- The `pressedfn` parameter is the function that will be called when this hotkey is pressed.
---
--- The `releasedfn` parameter is the function that will be called when this hotkey is released; this field is optional (i.e. may be nil or omitted).

local function wrap(fn)
  return function()
    if fn then
      local ok, err = xpcall(fn, debug.traceback)
      if not ok then hs.showerror(err) end
    end
  end
end

function hotkey.new(mods, key, pressedfn, releasedfn)
  local keycode = keycodes.map[key:lower()]

  local _pressedfn = wrap(pressedfn)
  local _releasedfn = wrap(releasedfn)

  local k = hotkey._new(mods, keycode, _pressedfn, _releasedfn)
  return k
end

--- hs.hotkey.bind(mods, key, pressedfn, releasedfn) -> hotkey
--- Constructor
--- Shortcut for: return hs.hotkey.new(mods, key, pressedfn, releasedfn):enable()
function hotkey.bind(...)
  return hotkey.new(...):enable()
end

return hotkey
