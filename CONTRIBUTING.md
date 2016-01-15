# Contributing to Hammerspoon

Hammerspoon is composed of three separate logical areas - a Lua runtime wrapper framework called [LuaSkin](http://www.hammerspoon.org/docs/LuaSkin/Classes/LuaSkin/index.html#), the core Hammerspoon app which houses the LuaSkin/Lua runtime and provides the ability to load extensions, and [various extension modules](https://github.com/Hammerspoon/hammerspoon/tree/master/extensions) that [expose system APIs](http://www.hammerspoon.org/docs/) to the user's Lua code.

## How is everything built?

The app itself is built using Xcode. You must open `Hammerspoon.xcworkspace` rather than `Hammerspoon.xcodeproj`. If you open the latter, your build will fail because Xcode will not know about the Cocoapods that Hammerspoon depends on (see our [`Podfile`](https://github.com/Hammerspoon/hammerspoon/blob/master/Podfile) for the current list of required pods).

The extension modules are built before the core Hammerspoon binary as target dependencies. Each extension is defined as an Xcode target in its own right, although there is usually no reason to build these targets manually. During the late stages of the build process, a script ([`scripts/copy_extensions_to_bundle.sh`](https://github.com/Hammerspoon/hammerspoon/blob/master/scripts/copy_extensions_to_bundle.sh)) collects all of the compiled extension libraries and their associated Lua components, and inserts them into the final `Hammerspoon.app` bundle.

## Contributing to the core app or LuaSkin
This is generally very simple in terms of the workflow, but there's less likely to be any reason to work on the core app:

* Clone our GitHub [repository](https://github.com/Hammerspoon/hammerspoon)
* Open `Hammerspoon.xcworkspace` in Xcode (Note that you'll generally need the latest available version of Xcode)
* Make the changes you want
* Push them up to a fork on GitHub
* Propose a Pull Request on GitHub
* Talk to us in #hammerspoon on Freenode if you need any guidance

## Contributing to the extensions

This is really where the meat of Hammerspoon is. Extensions can either be pure Lua or a mixture of Lua and Objective-C (although since they are just dynamically loaded libraries, they could ultimately be compiled in almost any language, if there is a sufficiently compelling reason).

*Note*: all APIs provided by extensions should follow the camelCase naming convention. This does not need to apply to an extension's internal functions, just the ones presented to Lua.

Modifying an existing extension should follow the simple workflow above for the core app.

### Writing a new, pure-Lua extension ###

These extensions generally provide useful helper functionality for users (e.g. abstracting other extensions).

To create such an extension:

* Clone the Hammerspoon git repository
* cd into the `extensions` directory
* Make a directory for your extension
* Create an `init.lua` to contain your code. It should behave like any normal Lua library - that is to say, your job is to return a table containing functions/methods/constants/etc
* Ensure you document your API in our preferred format (see the code for almost any existing module for reference)
* Edit `scripts/copy_extensions_to_bundle.sh` and add your module name to the `HS_LUAONLY` section
* Build Hammerspoon and test your extension
* Push your changes up to a fork on GitHub
* Propose a Pull Request on GitHub
* Talk to us in #hammerspoon on Freenode if you need any guidance

### Writing a new mixed Lua/Objective-C extension ###

These extensions generally expose an OS level API for users to automate (e.g. adjusting screen brightness using IOKit).

To create such an extension:

* Clone the Hammerspoon git repository
* Create the directories/files for your extension:
  * cd into the `extensions` directory
  * Make a directory for your extension
  * Create an `init.lua` to load your Objective-C code and contain any additional Lua code. You might find it easier to provide much of your API in Lua and just provide undocumented API from Objective C that does the minimum work possible. The choice is ultimately down to you, depending on the nature of the work the extension is doing.
  * Create an `internal.m` to contain your Objective-C code. Please use the LuaSkin methods to do as much work as possible, they are well tested and in most extensions can reduce the amount of Lua C API calls to almost zero. Not all of our extensions have been fully converted to LuaSkin yet (a good example is [`hs.chooser`](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/chooser/internal.m))
  * Right click on the `extensions` group in Xcode and add a new sub-group for your extension, then right click on the sub-group and add your `init.lua` and `internal.m` files (and any supporting `.h`/`.c`/`.m`/etc files)
* Configure Xcode to build your extension and include it in the `Hammerspoon.app` bundle:
  * Click on the `Hammerspoon` workspace at the very top of the Xcode Navigator (i.e. the bar on the left)
  * Right click on `alert` and choose `Duplicate`, which creates `alert copy` at the bottom of the list.
  * Rename the copy and drag it to the right place in the list (alphabetically)
  * Click on the target you just created, remove `internal.m` from the `Compile Sources` build phase, add in the `.m` files from your new module
  * Check the `Link Binary With Libraries` section for any frameworks you need to add. Typically this will just mean adding `Fabric.framework` from the top level of the Hammerspoon source tree if you've included `hammerspoon.h`, plus any additional system frameworks you need to link against.
  * Click on the `Hammerspoon` target (not the project), and in the `Target Dependencies` build phase, add the module target you just created
  * Click the menu item Product → Scheme → Manage Schemes, find `alert copy`, rename it and move it to the right place in the list of schemes
  * Edit `scripts/copy_extensions_to_bundle.sh` and add your module name to the `HS_MODULES` section. *Note*: Some modules may also need to copy extra files into the app bundle, in which case add a "special copier" to the bottom of the script.
* Build Hammerspoon and test your extension
* Push your changes up to a fork on GitHub
* Propose a Pull Request on GitHub
* Talk to us in #hammerspoon on Freenode if you need any guidance

### Documenting your extension

Both Lua and Objective-C portions of an extension should contain in-line documention of all of the functions they expose to users of the extension.

The format for docstrings should follow the standard described below. Note that for Lua files, the lines should begin with `---` and for Objective C files, the lines should begin with `///`.

#### Constants

```lua
--- hs.foo.someConstant
--- Constant
--- This defines the value of a thing
```

#### Variables

```lua
--- hs.foo.someVariable
--- Variable
--- This lets you influence the behaviour of this extension
```

#### Functions

Note that a function is any API function provided by an extension, which doesn't relate to an object created by the extension.

The `Parameters` and `Returns` sections should always be present. If there is nothing to describe there, simply list `* None`. The `Notes` section is optional and should only be present if there are useful notes.

```lua
--- hs.foo.someFunction(bar[, baz]) -> string or nil
--- Function
--- This is a one-line description of the function
---
--- Parameters:
---  * bar - A value for doing something
---  * baz - Some optional other value. Defaults to 'abc'
---
--- Returns:
---  * A string with some important result, or nil if an error occurred
---
--- Notes:
---  * An important first note
---  * Another important note
```

#### Methods

Note that a method is any function provided by an extension which relates to an object created by that extension. They are still technically functions, but the signature is differentiated by the presence of a `:`

The `Parameters` and `Returns` sections should always be present. If there is nothing to describe there, simply list `* None`. The `Notes` section is optional and should only be present if there are useful notes.

```lua
--- hs.foo:someMethod() -> bool
--- Method
--- This is a one-line description of the method
---
--- Parameters:
---  * None
---
--- Returns:
---  * Boolean indicating whether the operation succeeded.
```

### Third party extension distribution

While we want to have Hammerspoon shipping as many useful extensions as possible, there may be reasons for you to ship your extension separately. It would probably be easier to do this in binary form, following the init.lua/internal.so form that Hammerspoon uses, then users can just download your extension into `~/.hammerspoon/<YOUR_EXTENSION_NAME>/`.

If you do choose this route, please list your extension at [https://github.com/Hammerspoon/hammerspoon/wiki/Third-Party-Extensions](https://github.com/Hammerspoon/hammerspoon/wiki/Third-Party-Extensions) so users can discover it easily.
