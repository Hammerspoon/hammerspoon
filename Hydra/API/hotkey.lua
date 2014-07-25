hotkey.keycodes = hotkey._cachekeycodes()

--- hotkey.bind(mods, key, pressedfn, releasedfn) -> hotkey
--- Shortcut for: return hotkey.new(mods, key, pressedfn, releasedfn):enable()
function hotkey.bind(...)
  return hotkey.new(...):enable()
end

--- hotkey.inputsourcechanged()
--- Called when your input source (i.e. qwerty, dvorak, colemac) changes.
--- Default implementation does nothing; you may override this to rebind your hotkeys or whatever.
function hotkey.inputsourcechanged()
end

function hotkey._inputsourcechanged()
  hotkey.keycodes = hotkey._cachekeycodes()
  hotkey.inputsourcechanged()
end
