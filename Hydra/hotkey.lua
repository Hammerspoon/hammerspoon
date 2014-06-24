api.hotkey.keys = {}
api.hotkey.keys.n = 0

doc.api.hotkey.new = {"api.hotkey.new(mods, key, fn) -> hotkey", "Creates a new hotkey that can be enabled. Mods is a table containing any of the elements {cmd, ctrl, alt, shift}. Key may be any 1-character string, or 'F1', 'Enter', etc. Both are case-insensitive. The hotkey has the public fields: key, mods, fn."}
local hotkey_metatable = {__index = api.hotkey}
function api.hotkey.new(mods, key, fn)
  return setmetatable({mods = mods, key = key, fn = fn}, hotkey_metatable)
end

doc.api.hotkey.enable = {"api.hotkey:enable() -> hotkey", "Registers the hotkey's fn as the callback when the user presses key while holding mods."}
function api.hotkey:enable()
  local uid = api.hotkey.keys.n + 1
  api.hotkey.keys.n = uid

  api.hotkey.keys[uid] = self
  self.__uid = uid

  return self:_enable()
end

doc.api.hotkey.disable = {"", ""}
function api.hotkey:disable()
  api.hotkey.keys[self.__uid] = nil
  self.__uid = nil

  return self:_disable()
end

doc.api.hotkey.bind = {"api.hotkey.bind(...) -> hotkey", "Shortcut for: return api.hotkey.new(...):enable()"}
function api.hotkey.bind(...)
  return api.hotkey.new(...):enable()
end

doc.api.hotkey.disableall = {"api.hotkey.disableall()", "Disables all hotkeys; automatically called when user config reloads."}
function api.hotkey.disableall()
  for i, hotkey in pairs(api.hotkey.keys) do
    if hotkey and i ~= "n" then hotkey:disable() end
  end
  api.hotkey.keys.n = 0
end
