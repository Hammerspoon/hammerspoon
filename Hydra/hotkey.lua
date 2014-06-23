api.doc.hotkey.keys = {"api.hotkey.keys = {}", "List of all hotkeys registered since last reload; also includes currently-disabled hotkeys."}
api.hotkey.keys = {}

api.doc.hotkey.bind = {"api.hotkey.bind(...) -> hotkey", "Convenience function to combine hotkey() and hotkey:enable()"}
function api.hotkey.bind(...)
  return api.hotkey(...):enable()
end

api.doc.hotkey.new = {"api.hotkey.new(mods, key, fn) -> hotkey", "Creates a new hotkey that can be enabled. Mods is a table containing any of the elements {cmd, ctrl, alt, shift}. Key may be any 1-character string, or 'F1', 'Enter', etc. Both are case-insensitive. The hotkey has the public fields: key, mods, fn."}
local hotkey_metatable = {__index = api.hotkey}
local function new_hotkey(this, mods, key, fn)
  return setmetatable({mods = mods, key = key, fn = fn}, hotkey_metatable)
end
setmetatable(api.hotkey, {__call = new_hotkey})

api.doc.hotkey.enable = {"api.hotkey:enable() -> hotkey", "Registers the hotkey's fn as the callback when the user presses key while holding mods."}
function api.hotkey:enable()
  table.insert(api.hotkey.keys, self)
  self.__uid = #api.hotkey.keys
  return self:_enable()
end
