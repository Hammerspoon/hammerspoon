--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--              P L U G I N     L O A D E R     L I B R A R Y                 --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Module created by David Peterson (https://github.com/randomeizer).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local settings						= require("hs.settings")
local fs							= require("hs.fs")

local tools							= require("hs.fcpxhacks.modules.tools")

local log							= require("hs.logger").new("plugins")
local inspect						= require("hs.inspect")

--------------------------------------------------------------------------------
-- THE MODULE:
--------------------------------------------------------------------------------

local mod = {}

mod.CACHE = {}

mod.SETTINGS_DISABLED = "fcpxHacks.plugins.disabled"

--- hs.plugins.loadPackage(package) -> boolean
--- Function
--- Loads any plugins present in the specified package. 
--- Any `*.lua` file, or folder containing an `init.lua` file will automatically be
--- loaded as a plugin.
---
--- Eg:
---
--- ```
--- plugins.loadPackage("hs.fcpxhacks.plugins")
--- ```
---
--- Parameters:
---  * package - The LUA package to look in
---
--- Returns:
---  * boolean - `true` if all plugins loaded successfully
---
function mod.loadPackage(package)
	local path = fs.pathToAbsolute("~/.hammerspoon/" .. package:gsub("%.", "/"))
	if not path then
		log.ef("The provided path does not exist: '%s'", package)
		return false
	end
	
	local attrs = fs.attributes(path)
	if not attrs or attrs.mode ~= "directory" then
		log.ef("The provided path is not a directory: '%s'", package)
		return false
	end
	
	local files = tools.dirFiles(path)
	for i,file in ipairs(files) do
		if file ~= "." and file ~= ".." then
			local filePath = path .. "/" .. file
			if fs.attributes(filePath).mode == "directory" then
				local attrs, err = fs.attributes(filePath .. "/init.lua")
				if attrs and attrs.mode == "file" then
					-- it's a plugin
					mod.load(package .. "." .. file)
				else
					-- it's a plain folder. Load it as a sub-package.
					mod.loadPackage(package .. "." .. file)
				end
			else
				local name = file:match("(.+)%.lua$")
				if name then
					mod.load(package .. "." .. name)
				end
			end
		end
	end
	
	return true
end


--- hs.plugins.load(package) -> boolean
--- Function
--- Loads a specific plugin with the specified path.
--- The plugin will only be loaded once, and the result of its `init(...)` function
--- will be cached for future calls.
---
--- Eg:
---
--- ```
--- plugins.load("hs.fcpxhacks.plugins.test.helloworld")
--- ```
---
--- Parameters:
---  * package - The LUA package to look in
---
--- Returns:
---  * the result of the plugin's `init(...)` function call.
---
function mod.load(pluginPath)
	-- log.df("Loading plugin '%s'", pluginPath)
	
	-- First, check the plugin is not disabled:
	if mod.isDisabled(pluginPath) then
		log.df("Plugin disabled: '%s'", pluginPath)
		return nil
	end
	
	local cache = mod.CACHE[pluginPath]
	if cache ~= nil then
		-- we've already loaded it
		return cache.instance
	end

	local plugin = require(pluginPath)
	if plugin == nil or type(plugin) ~= "table" then
		log.ef("Unable to load plugin '%s'.", pluginPath)
		return nil
	end
	
	local dependencies = {}
	if plugin.dependencies then
		-- log.df("Processing dependencies for '%s'.", pluginPath)
		for path,alias in pairs(plugin.dependencies) do
			if type(path) == "number" then
				-- no alias
				path = alias
				alias = nil
			end
			
			local dependency = mod.load(path)
			if dependency then
				dependencies[path] = dependency
				if alias then
					dependencies[alias] = dependency
				end
			else
				-- unable to load the dependency. Fail!
				log.ef("Unable to load dependency for plugin '%s': %s", pluginPath, path)
				return nil
			end
		end
	end
	
	-- initialise the plugin instance
	-- log.df("Initialising plugin '%s'.", pluginPath)
	local instance = nil
	
	if plugin.init then
		local status, err = pcall(function()
			instance = plugin.init(dependencies)
		end)

		if not status then
			log.ef("Error while initialising plugin '%s': %s", pluginPath, inspect(err))
			return nil
		end
	else
		log.wf("No init function for plugin: %s", pluginPath)
	end

	-- Default the return value to 'true'
	if instance == nil then
		instance = true
	end
	
	-- cache it
	mod.CACHE[pluginPath] = {plugin = plugin, instance = instance}
	-- return the instance
	log.df("Loaded plugin '%s'", pluginPath)
	return instance
end

function mod.disable(pluginPath)
	local disabled = settings.get(mod.SETTINGS_DISABLED) or {}
	disabled[pluginPath] = true
	settings.set(mod.SETTINGS_DISABLED, disabled)
	hs.reload()
end

function mod.enable(pluginPath)
	local disabled = settings.get(mod.SETTINGS_DISABLED) or {}
	disabled[pluginPath] = false
	settings.set(mod.SETTINGS_DISABLED, disabled)
	hs.reload()
end

function mod.isDisabled(pluginPath)
	local disabled = settings.get(mod.SETTINGS_DISABLED) or {}
	return disabled[pluginPath] == true
end

function mod.init(...)
	for i=1,select('#', ...) do
		package = select(i, ...)
		log.df("Loading plugin package '%s'", package)
		local status, err = pcall(function()
			mod.loadPackage(package)
		end)
		
		if not status then
			log.ef("Error while loading package '%s':\n%s", package, hs.inspect(err))
		end
	end
	
	return mod
end

setmetatable(mod, {__call = function(_, ...) return mod.load(...) end})

return mod