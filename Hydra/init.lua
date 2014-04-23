hotkey.keys = {}

function hotkey.callback(n)
   local hk = hotkey.keys[n]
   return hk.f()
end

local hotkey_instance = {}

function hotkey.new(key, mods, f)
   local hk = {
      key = key,
      mods = mods,
      f = f,
   }
   return setmetatable(hk, {__index = hotkey_instance})
end

function hotkey.bind(...)
   local hk = hotkey.new(...)
   hk:enable()
   return hk
end

function hotkey_instance:enable()
   table.insert(hotkey.keys, self)
   self._id = #hotkey.keys
   self._carbonkey = hotkey.register(self._id, self.key, self.mods)
end

function hotkey_instance:disable()
   hotkey.unregister(self._carbonkey)
   table.remove(hotkey.keys, self)
end

-- local hk = hotkey.new("d", {"cmd", "shift"}, function() print("i was finally called!!!") end)
-- hk:enable()

-- -- or

-- hotkey.bind("d", {"cmd", "shift"}, function() print("i was finally called!!!") end)
