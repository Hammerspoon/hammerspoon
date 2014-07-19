hotkey.keycodes = hotkey._cachekeycodes()

--- hotkey.bind(mods, key, pressedfn, releasedfn) -> hotkey
--- Shortcut for: return hotkey.new(mods, key, pressedfn, releasedfn):enable()
function hotkey.bind(...)
  return hotkey.new(...):enable()
end

--- hotkey.disableall()
--- Disables all hotkeys; automatically called when user config reloads.
function hotkey.disableall()
  local hotkeys = fnutils.filter(_registry, hydra._ishandlertypefn("hotkey"))
  fnutils.each(hotkeys, hotkey.disable)
end
