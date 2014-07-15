--- hotkey.bind(mods, key, fn) -> hotkey
--- Shortcut for: return hotkey.new(mods, key, fn):enable()
function hotkey.bind(...)
  return hotkey.new(...):enable()
end

--- hotkey.disableall()
--- Disables all hotkeys; automatically called when user config reloads.
function hotkey.disableall()
  hotkey.keys.n = nil
  -- FIXME: can't mutate table while iterating it!
  for _, hotkey in pairs(hotkey.keys) do hotkey:disable() end
  hotkey.keys.n = 0
end
