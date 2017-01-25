# Plugins

This is a simple plugin manager. 


## Functions

It has a few core functions:

### `plugins.init(...)`

This function will load all enabled plugins in the specified 'parent' package. For example, the default plugin path for FCPX Hacks is `hs.fcpxhacks.plugins`. This directory contains a collection of `*.lua` files or subdirectories. To initialse the system to load this path, you would call:

```lua
local plugins = require("hs.fcpxhacks.modules.plugins")
plugins.init("hs.fcpxhacks.plugins")
```

### `plugins.loadPlugin(...)`

This function loads a plugin directly. If it has dependencies, the dependencies will also be loaded (if possible). If successful, the result of the plugin's `init(dependencies)` function will be returned.

### `plugins.loadPackage(...)`

This function will load a package of plugins. If the package contains sub-packages, they will be loaded recursively.

## Plugin Modules

A plugin file should return a `plugin` table that allows the plugin to be initialised.

A plugin module can have a few simple functions and properties. The key ones are:

### `function plugin.init(dependencies)`

If the `init(dependencies)` function is present, it will be executed when the plugin is loaded. The `dependencies` parameter is a table containing the list of dependencies that the plugin defined


### `plugin.dependencies` table

This is a table with the list of other plugins that this plugin requires to be loaded prior to this plugin. Be careful of creating infinite loops of dependencies - we don't check for them currently!

It is defined like so:

```lua
plugin.dependencies = {
	"hs.fcpxhacks.plugins.myplugin",
	["hs.fcpxhacks.plugins.otherplugin"] = "otherplugin"
}
```

As you may have noted, there are two ways to specify a plugin is required. Either by simply specifying it as an 'array' item (the first example) or as a key/value (the second example). Doing the later allows you to specify an alias for the dependency, which can be used in the `init(...)` function, like so:

```lua
local plugin = {}

plugin.dependencies = {
	"hs.fcpxhacks.plugins.myplugin",
	["hs.fcpxhacks.plugins.otherplugin"] = "otherplugin"
}

function plugin.init(dependencies)
	local myplugin = dependencies["hs.fcpxhacks.plugins.myplugin"]
	local otherplugin = dependencies.otherplugin
	
	-- do other stuff with the dependencies
	
	return myinstance
end

return plugin
```
