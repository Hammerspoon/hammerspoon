local module={}

--- === hs.spoons ===
---
--- Utility and management functions for Spoons
--- Spoons are Lua plugins for Hammerspoon.
--- See http://www.hammerspoon.org/Spoons/ for more information

module._keys = {}

local log = hs.logger.new("spoons")

-- --------------------------------------------------------------------
-- Some internal utility functions

-- Interpolate table values into a string
-- From http://lua-users.org/wiki/StringInterpolation
local function interp(s, tab)
   return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

-- Read a whole file into a string
local function slurp(path)
   local f = assert(io.open(path))
   local s = f:read("*a")
   f:close()
   return s
end

--- hs.spoons.newSpoon(name, basedir, metadata)
--- Method
--- Create a skeleton for a new Spoon
---
--- Parameters:
---  * name: name of the new spoon, without the `.spoon` extension
---  * basedir: (optional) directory where to create the template. Defaults to `~/.hammerspoon/Spoons`
---  * metadata: (optional) table containing metadata values to be inserted in the template. Provided values are merged with the defaults. Defaults to:
---    ```
---    {
---      version = "0.1",
---      author = "Your Name <your@email.org>",
---      homepage = "https://github.com/Hammerspoon/Spoons",
---      license = "MIT - https://opensource.org/licenses/MIT",
---      download_url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/"..name..".spoon.zip"
---    }
---    ```
---  * template: (optional) absolute path of the template to use for the `init.lua` file of the new Spoon. Defaults to the `templates/init.tpl` file included with Hammerspoon.
---
--- Returns:
---  * The full directory path where the template was created, or `nil` if there was an error.
function module.newSpoon(name, basedir, metadata, template)
   -- Default value for basedir
   if basedir == nil or basedir == "" then
      basedir = hs.configdir .. "/Spoons/"
   end
   -- Ensure basedir ends with a slash
   if not string.find(basedir, "/$") then
      basedir = basedir .. "/"
   end
   local meta={
      version = "0.1",
      author = "Your Name <your@email.org>",
      homepage = "https://github.com/Hammerspoon/Spoons",
      license = "MIT - https://opensource.org/licenses/MIT",
      download_url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/"..name..".spoon.zip",
      description = "A new Sample Spoon"
   }
   if metadata then
      for k,v in pairs(metadata) do meta[k] = v end
   end
   meta["name"]=name

   local dirname = basedir .. name .. ".spoon"
   if hs.fs.mkdir(dirname) then
      local f=assert(io.open(dirname .. "/init.lua", "w"))
      local template_file = template or module.resource_path("templates/init.tpl")
      local text=slurp(template_file)
      f:write(interp(text, meta))
      f:close()
      return dirname
   end
   return nil
end

--- hs.spoons.script_path()
--- Method
--- Return path of the current spoon.
---
--- Parameters:
---  * n - (optional) stack level for which to get the path. Defaults to 2, which will return the path of the spoon which called `script_path()`
---
--- Returns:
---  * String with the path from where the calling code was loaded.
function module.script_path(n)
   if n == nil then n = 2 end
   local str = debug.getinfo(n, "S").source:sub(2)
   return str:match("(.*/)")
end

--- hs.spoons.resource_path(partial)
--- Method
--- Return full path of an object within a spoon directory, given its partial path.
---
--- Parameters:
---  * partial - path of a file relative to the Spoon directory. For example `images/img1.png` will refer to a file within the `images` directory of the Spoon.
---
--- Returns:
---  * Absolute path of the file. Note: no existence or other checks are done on the path.
function module.resource_path(partial)
   return(module.script_path(3) .. partial)
end

--- hs.spoons.bindHotkeysToSpec(def, map)
--- Method
--- Map a number of hotkeys according to a definition table
---
--- Parameters:
---  * def - table containing name-to-function definitions for the hotkeys supported by the Spoon. Each key is a hotkey name, and its value must be a function that will be called when the hotkey is invoked.
---  * map - table containing name-to-hotkey definitions, as supported by [bindHotkeys in the Spoon API](https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md#hotkeys). Not all the entries in `def` must be bound, but if any keys in `map` don't have a definition, an error will be produced.
---
--- Returns:
---  * None
function module.bindHotkeysToSpec(def,map)
   local spoonpath = module.script_path(3)
   for name,key in pairs(map) do
      if def[name] ~= nil then
         local keypath = spoonpath .. name
         if module._keys[keypath] then
            module._keys[keypath]:delete()
         end
         module._keys[keypath]=hs.hotkey.bindSpec(key, def[name])
      else
         log.ef("Error: Hotkey requested for undefined action '%s'", name)
      end
   end
end

--- hs.spoons.list()
--- Method
--- Return a list of installed/loaded Spoons
---
--- Parameters:
---  * only_loaded - only return loaded Spoons (skips those that are installed but not loaded). Defaults to `false`
---
--- Returns:
---  * Table with a list of installed/loaded spoons (depending on the value of `only_loaded`). Each entry is a table with the following entries:
---    * `name` - Spoon name
---    * `loaded` - boolean indication of whether the Spoon is loaded (`true`) or only installed (`false`)
---    * `version` - Spoon version number. Available only for loaded Spoons.
function module.list(only_loaded)
   local iterfn, dirobj = hs.fs.dir(hs.configdir .. "/Spoons")
   local res = {}
   repeat
      local f = dirobj:next()
      if f then
         if string.match(f, ".spoon$") then
            local s = f:gsub(".spoon$", "")
            local l = (spoon[s] ~= nil)
            if (not only_loaded) or l then
               local new = { name = s, loaded = l }
               if l then new.version = spoon[s].version end
               table.insert(res, new)
            end
         end
      end
   until f == nil
   return res
end

--- hs.spoons.isInstalled(name)
--- Method
--- Check if a given Spoon is installed.
---
--- Parameters:
---  * name - Name of the Spoon to check.
---
--- Returns:
---  * If the Spoon is installed, it returns a table with the Spoon information as returned by `list()`. Returns `nil` if the Spoon is not installed.
function module.isInstalled(name)
   local list = module.list()
   for i,v in ipairs(list) do
      if v.name == name then
         return v
      end
   end
   return nil
end

--- hs.spoons.isLoaded(name)
--- Method
--- Check if a given Spoon is loaded.
---
--- Parameters:
---  * name - Name of the Spoon to check.
---
--- Returns:
---  * `true` if the Spoon is loaded, `nil` otherwise.
function module.isLoaded(name)
   local list = module.list()
   for i,v in ipairs(list) do
      if v.name == name then
         return v.loaded
      end
   end
   return nil
end

--- hs.spoons.use(name, arg)
--- Method
--- Declaratively load and configure a Spoon
---
--- Parameters:
---  * name - the name of the Spoon to load (without the `.spoon` extension).
---  * arg - if provided, can be used to specify the configuration of the Spoon. The following keys are recognized (all are optional):
---    * config - a table containing variables to be stored in the Spoon object to configure it. For example, `config = { answer = 42 }` will result in `spoon.<LoadedSpoon>.answer` being set to 42.
---    * hotkeys - a table containing hotkey bindings. If provided, will be passed as-is to the Spoon's `bindHotkeys()` method. The special string `"default"` can be given to use the Spoons `defaultHotkeys` variable, if it exists.
---    * fn - a function which will be called with the freshly-loaded Spoon object as its first argument.
---    * loglevel - if the Spoon has a variable called `logger`, its `setLogLevel()` method will be called with this value.
---    * start - if `true`, call the Spoon's `start()` method after configuring everything else.
---  * noerror - if `true`, don't log an error if the Spoon is not installed, simply return `nil`.
---
--- Returns:
---  * `true` if the spoon was loaded, `nil` otherwise
function module.use(name, arg, noerror)
   log.df("hs.spoons.use(%s, %s)", name, hs.inspect(arg))
   if not arg then arg = {} end
   if hs.spoons.isInstalled(name) then
      local spn=hs.loadSpoon(name)
      if spn then
         if arg.loglevel and spn.logger then
            spn.logger.setLogLevel(arg.loglevel)
         end
         if arg.config then
            for k,v in pairs(arg.config) do
               log.df("Setting config: spoon.%s.%s = %s", name, k, hs.inspect(v))
               spn[k] = v
            end
         end
         if arg.hotkeys then
            local mapping = arg.hotkeys
            if mapping == 'default' then
               if spn.defaultHotkeys then
                  mapping = spn.defaultHotkeys
               else
                  log.ef("Default bindings requested, but spoon %s does not have a defaultHotkeys definition", name)
               end
            end
            if type(mapping) == 'table' then
               log.df("Binding hotkeys: spoon.%s:bindHotkeys(%s)", name, hs.inspect(arg.hotkeys))
               spn:bindHotkeys(mapping)
            end
         end
         if arg.fn then
            log.df("Calling configuration function %s", hs.inspect(arg.fn))
            arg.fn(spn)
         end
         if arg.start then
            log.df("Calling spoon.%s:start()", name)
            spn:start()
         end
         return true
      else
         log.ef("I could not load spoon %s\n", name)
      end
   else
      if not noerror then
         log.ef("Spoon %s is not installed - please install it and try again.", name)
      end
   end
   return nil
end

return module
