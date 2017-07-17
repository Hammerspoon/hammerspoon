--- === ${name} ===
---
--- ${description}
---
--- Download: [${download_url}](${download_url})

local obj={}
obj.__index = obj

-- Metadata
obj.name = "${name}"
obj.version = "${version}"
obj.author = "${author}"
obj.homepage = "${homepage}"
obj.license = "${license}"

--- ${name}.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('${name}')

--- Some internal variable
obj.key_hello = nil

--- ${name}.some_config_param
--- Variable
--- Some configuration parameter
obj.some_config_param = true

--- ${name}:sayHello()
--- Method
--- Greet the user
function obj:sayHello()
   hs.alert.show("Hello!")
   return self
end

--- ${name}:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for ${name}
---
--- Parameters:
---  * mapping - A table containing hotkey objifier/key details for the following items:
---   * hello - Say Hello
function obj:bindHotkeys(mapping)
   if mapping["hello"] then
      if (self.key_hello) then
         self.key_hello:delete()
      end
      self.key_hello = hs.hotkey.bindSpec(mapping["hello"], function() self:sayHello() end)
   end
end

return obj
