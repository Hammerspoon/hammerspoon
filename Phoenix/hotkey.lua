local hotkey = {}

local fp = require("fp")

hotkey.keys = {}

__api.hotkey_setup(function(uid)
    local k = hotkey.keys[uid]
    k.fn()
    return true -- TODO: allow the function itself to tell us what to return
end)

local hotkey_instance = {}

function hotkey.new(mods, key, fn)
  local k = {}
  k.mods = fp.map(mods, string.lower)
  k.key = key
  k.fn = fn
  return setmetatable(k, {__index = hotkey_instance})
end

function hotkey_instance:enable()
  self.__uid = #hotkey.keys + 1
  hotkey.keys[self.__uid] = self
  self.__carbonkey = __api.hotkey_register(fp.contains(self.mods, "cmd"),
                                           fp.contains(self.mods, "ctrl"),
                                           fp.contains(self.mods, "alt"),
                                           fp.contains(self.mods, "shift"),
                                           self.key,
                                           self.__uid)
  return self
end

function hotkey_instance:disable()
  print(self.__carbonkey)
  __api.hotkey_unregister(self.__carbonkey)
end

return hotkey
