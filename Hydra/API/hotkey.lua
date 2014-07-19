hotkey.keycodes = hotkey._cachekeycodes()

--- hotkey.bind(mods, key, pressedfn, releasedfn) -> hotkey
--- Shortcut for: return hotkey.new(mods, key, pressedfn, releasedfn):enable()
function hotkey.bind(...)
  return hotkey.new(...):enable()
end
