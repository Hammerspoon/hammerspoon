# Hammerspoon Spoon Plugins Documentation

* [What is a Spoon?](#what-is-a-spoon)
* [Where do I get Spoons from?](#where-do-i-get-spoons-from)
* [How do I install a Spoon?](#how-do-i-install-a-spoon)
* [How do I use a Spoon?](#how-do-i-use-a-spoon)
    * [Loading a Spoon](#loading-a-spoon)
    * [Integrating into your configuration](#integrating-into-your-configuration)
* [How do I create a Spoon?](#how-do-i-create-a-spoon)
    * [API Conventions](#api-conventions)
        * [Naming](#naming)
        * [Initialisation](#initialisation)
        * [Metadata](#metadata)
        * [Starting/Stopping](#startingstopping)
        * [Hotkeys](#hotkeys)
        * [Other](#other)
    * [Documentation](#documentation)
        * [Writing](#writing)
        * [Generating](#generating)
    * [Loading files](#loading-files)
        * [Code](#code)
        * [Assets](#assets)

## What is a Spoon?

Spoons are intended to be pure-Lua plugins for users to use in their Hammerspoon configs.

As a community, we have created many great configurations for Hammerspoon, but sharing code between them is hard and fragile. Spoons have been created as a way to address these issues.
Users should be able to download a Spoon and quickly integrate it into their config without worrying about what it is doing internally.

This is possible because of two things:

 * Infrastructure within Hammerspoon for loading Lua code from Spoons
 * The authors of Spoons sticking, wherever possible, to a standard API for users to use

## Where do I get Spoons from?

The official repository of Spoons is [https://www.hammerspoon.org/Spoons](https://www.hammerspoon.org/Spoons) (the source for which can be found at [https://github.com/Hammerspoon/Spoons](https://github.com/Hammerspoon/Spoons)), but authors may choose to distribute them separately from their own sites.

## How do I install a Spoon?

Spoons should be distributed as `.zip` files. Simply download one, uncompress it (if your browser hasn't done that part automatically) and double click on the Spoon. Hammerspoon will install it for you in `~/.hammerspoon/Spoons/`

## How do I use a Spoon?

There are two parts to this, loading the spoon, and integrating it into your configuration.
Hopefully the Spoon came with some documentation, either on its homepage or in `~/.hammerspoon/Spoons/NAME.spoon`. There you should find some documentation of the API offered by the Spoon, and any special requirements it has.

### Loading a Spoon

For most Spoons, simply add `hs.loadSpoon("NAME")` to your Hammerspoon config (note that `NAME` should *not* include the `.spoon` extension). This will make the spoon available in the global Lua namespace as `spoon.NAME`.

After loading a Spoon, you are responsible for calling its `start()` method if it has one before using it.

Note that `hs.loadSpoon()` uses `package.path` to find Spoons. Hence you can have it look for Spoons in other paths by adding those paths to `package.path` as follows:

```lua
-- Look for Spoons in ~/.hammerspoon/MySpoons as well
package.path = package.path .. ";" ..  hs.configdir .. "/MySpoons/?.spoon/init.lua"
```

This can be useful if you have Spoons you are developing for example.

### Integrating into your configuration

In most cases, the API should take roughly this form:

 * `NAME:init()` - this is called automatically by `hs.loadSpoon()` and will do any initial setup work required, but should generally not start taking any actions
 * `NAME:start()` - if any kind of background work is necessary, this method will start it
 * `NAME:stop()` - if any kind of background work is running, this method will stop it
 * `NAME:bindHotkeys(mapping)` - this method is used to tell the Spoon how to bind hotkeys for its various functions. Depending on the Spoon, these hotkeys may be bound immediately, or when `:start()` is called. This method should accept a single argument, a table in the form:

```lua
  { someFeature = {{"cmd", "alt"}, "f"},
    otherFeature = {{"shift", "ctrl"}, "b"}}
```

The Spoon should also provide some standard metadata:

 * `NAME.name` - A string containing the name of the Spoon
 * `NAME.version` - A string containing the version number of the Spoon
 * `NAME.author` - A string containing the name/email of the spoon's author
 * `NAME.license` - A string containing some information about the license that applies to the Spoon, ideally including a URL to the license

and optionally:

 * `NAME.homepage` - A string containing a URL to the Spoon's homepage

Many Spoons will offer additional API points on top of these, and you should consult their documentation to learn more.

## How do I create a Spoon?

Ultimately a Spoon can be as little as a directory whose name ends `.spoon`, with an `init.lua` inside it.

However, Spoons offer the most value to users of Hammerspoon when they conform to an API convention, allowing users to interact with all of their Spoons in very similar ways.

### API Conventions

#### Naming

 * Spoon names should use TitleCase
 * Spoon methods/variables/constants/etc. should use camelCase

#### Initialisation

When a user calls `hs.loadSpoon()`, Hammerspoon will load and execute `init.lua` from the relevant Spoon.

You should generally not perform any work, map any hotkeys, start any timers/watchers/etc. in the main scope of your `init.lua`. Instead, it should simply prepare an object with methods to be used later, then return the object.

If the object you return has an `:init()` method, Hammerspoon will call it automatically (although users can override this behaviour, so be sure to document your `:init()` method).

In the `:init()` method, you should do any work that is necessary to prepare resources for later use, although generally you should not be starting any timers/watchers/etc. or mapping any hotkeys here.

#### Metadata

You should include at least the following properties on your object:

 * `.name` - The name of your Spoon
 * `.version` - The version of your Spoon
 * `.author` - Your name and optionally your email address
 * `.license` - The software license that applies to your Spoon, ideally with a link to the text of the license (e.g. on [https://opensource.org/](https://opensource.org/))

and optionally:

 * `.homepage` - A URL for the home of your Spoon, e.g. its GitHub repo

#### Starting/Stopping

If your Spoon provides some kind of background activity, e.g. timers, watchers, spotlight searches, etc. you should generally activate them in a `:start()` method, and de-activate them in a `:stop()` method

#### Hotkeys

If your Spoon provides actions that a user can map to hotkeys, you should expose a `:bindHotKeys()` method. The method should accept a single parameter, which is a table.
The keys of the table should be strings that describe the action performed by the hotkeys, and the values of the table should be tables containing modifiers and keynames/keycodes and, optionally, a message to be displayed via `hs.alert()` when the hotkey has been triggered.

For example, if the user wants to map two of your actions, `show` and `hide`, they would pass in:

```lua
  {
    show={{"cmd", "alt"}, "s", message="Show"},
    hide={{"cmd", "alt"}, "h"}
  }
```

Your `:bindHotkeys()` method now has all of the information it needs to bind hotkeys to its methods.

While you might want to verify the contents of the table, it seems reasonable to be fairly limited in the extent, so long as you have documented the method well.

The function `hs.spoons.bindHotkeysToSpec()` can do most of the hard work of the mappings for you. For exmaple, the following would allow binding of actions `show` and `hide` to `showMethod()` and `hideMethod()` respectively:

```lua
function MySpoon:bindHotKeys(mapping)
  local spec = {
    show = hs.fnutils.partial(self.showMethod, self),
    hide = hs.fnutils.partial(self.hideMethod, self),
  }
  hs.spoons.bindHotkeysToSpec(spec, mapping)
  return self
end
```

#### Other

You can present any other methods you want, and while they are all technically accessible to the user, you should only document the ones you actually intend to be public API.

### Documentation

#### Writing

Spoon methods/variables/etc. should be documented using the same docstring format that Hammerspoon uses for its own API. An example of a method for adding a USB device to a Spoon that takes actions when USB devices are connected, might look like this:

```lua
--- USBObserver:addDevice(vendorID, productID[, name])
--- Method
--- Adds a device to USBObserver's watch list
---
--- Parameters:
---  * vendorID - A number containing the vendor ID of a USB device
---  * productID - A number containing the vendor ID of a USB device
---  * name - An optional string containing the name of a USB device
---
--- Returns:
---  * A boolean, true if the device was added, otherwise false
```

By convention in Hammerspoon, methods tend to return the object they belong to (so methods can be chained, e.g. `foo:bar():baz()`), but this isn't always appropriate.

#### Generating

Several tools are able to operate on the docstrings used by Hammerspoon and Spoons. In the simplest case, each Spoon should include a `docs.json` file which is little more than the various docstrings collected together.
This file can be generated using the Hammerspoon command line tool (see [https://www.hammerspoon.org/docs/hs.ipc.html#cliInstall](https://www.hammerspoon.org/docs/hs.ipc.html#cliInstall)):

```bash
cd /path/too/your/Spoon
hs -c "hs.doc.builder.genJSON(\"$(pwd)\")" | grep -v "^--" > docs.json
```

Any Spoons that are submitted to the official Spoons repository will have their HTML documentation generated and hosted by GitHub.

If you also want to generate HTML/Markdown versions of your documentation for your own purposes:

 * Clone [https://github.com/Hamerspoon/hammerspoon](https://github.com/Hammerspoon/hammerspoon)
 * Install the required Python dependencies (e.g. `pip install --user -r requirements.txt` in the Hammerspoon repo)
 * Then in your Spoon's directory, run:

```bash
/path/to/hammerspoon_repo/scripts/docs/bin/build_docs.py --templates /path/to/hammerspoon_repo/scripts/docs/templates/ --output_dir . --json --html --markdown --standalone .
```

This will search the current working director for any `.lua` files, extract docstrings from them, and write `docs.json` to the current directory, along with HTML and Markdown outputs. See `build_docs.py --help` for more options.

### Loading files

If your Spoon grows more complex than just an `init.lua`, a problem you will quickly run into is how you can load extra `.lua` files, or other types of resources (e.g. images).

There is, however, a simple way to discover the true path of your Spoon on the filesystem. Simply use the `hs.spoons.scriptPath()` function:

```lua
-- Get path to Spoon's init.lua script
obj.spoonPath = hs.spoons.scriptPath()
```
#### Assets

To access assets bundled with your Spoon, use the `hs.spoons.resourcePath()` function:

```lua

-- Get path to a resource bundled with the Spoon
obj.imagePath = hs.spoons.resourcePath("images/someImage.png")
```

#### Code

You cannot use `require()` to load `.lua` files in a Spoon, instead you should use:

```lua
dofile(hs.spoons.resourcePath("someCode.lua"))
```

and the `someCode.lua` file will be loaded and executed (and if it returns anything, you can capture those values from `dofile()`)
