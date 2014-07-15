--- hotkey.bind(mods, key, fn) -> hotkey
--- Shortcut for: return hotkey.new(mods, key, fn):enable()
function hotkey.bind(...)
  return hotkey.new(...):enable()
end

--- hotkey.disableall()
--- Disables all hotkeys; automatically called when user config reloads.
function hotkey.disableall()
  fnutils.each(fnutils.copy(hotkey._keys), hotkey.disable)
end
