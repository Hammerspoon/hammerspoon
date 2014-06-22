api.hotkey.keys = {}

function api.hotkey.bind(...)
  return api.hotkey(...):enable()
end

local hotkey_metatable = {__index = api.hotkey}
local function new_hotkey(this, mods, key, fn)
  return setmetatable({mods = mods, key = key, fn = fn}, hotkey_metatable)
end
setmetatable(api.hotkey, {__call = new_hotkey})

function api.hotkey:enable()
  table.insert(api.hotkey.keys, self)
  self.__uid = #api.hotkey.keys
  return self:_enable()
end
