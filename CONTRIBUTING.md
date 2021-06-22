# Contributing to Hammerspoon

* [How is everything built?](#how-is-everything-built)
    * [Making frequent local rebuilds more convenient](#making-frequent-local-rebuilds-more-convenient)
* [Contributing to the core app or LuaSkin](#contributing-to-the-core-app-or-luaskin)
* [Contributing to the extensions](#contributing-to-the-extensions)
    * [Writing a new, pure-Lua extension](#writing-a-new-pure-lua-extension)
    * [Writing a new mixed Lua/Objective-C extension](#writing-a-new-mixed-luaobjective-c-extension)
    * [Documenting your extension](#documenting-your-extension)
        * [Constants](#constants)
        * [Variables](#variables)
        * [Functions](#functions)
        * [Methods](#methods)
    * [Testing](#testing)
    * [Third party extension distribution](#third-party-extension-distribution)

Hammerspoon is composed of three separate logical areas - a Lua runtime wrapper framework called [LuaSkin](http://www.hammerspoon.org/docs/LuaSkin/Classes/LuaSkin/index.html#), the core Hammerspoon app which houses the LuaSkin/Lua runtime and provides the ability to load extensions, and [various extension modules](https://github.com/Hammerspoon/hammerspoon/tree/master/extensions) that [expose system APIs](http://www.hammerspoon.org/docs/) to the user's Lua code.

## How is everything built?

The app itself is built using Xcode. You must open `Hammerspoon.xcworkspace` rather than `Hammerspoon.xcodeproj`. If you open the latter, your build will fail because Xcode will not know about the Cocoapods that Hammerspoon depends on (see our [`Podfile`](https://github.com/Hammerspoon/hammerspoon/blob/master/Podfile) for the current list of required pods). On versions of macOS prior to Catalina [Python 3](https://www.python.org) will need to be installed for the build to work.

The extension modules are built before the core Hammerspoon binary as target dependencies. Each extension is defined as an Xcode target in its own right, although there is usually no reason to build these targets manually. During the late stages of the build process, a script ([`scripts/copy_extensions_to_bundle.sh`](https://github.com/Hammerspoon/hammerspoon/blob/master/scripts/copy_extensions_to_bundle.sh)) collects all of the compiled extension libraries and their associated Lua components, and inserts them into the final `Hammerspoon.app` bundle.

### Making frequent local rebuilds more convenient
[Self-signing your builds](https://github.com/Hammerspoon/hammerspoon/issues/643#issuecomment-158291705) will keep you from having to re-enable permissions for your locally built copy.

Create a self-signed Code Signing certificate named 'Internal Code Signing' or similar as described [here](http://bd808.com/blog/2013/10/21/creating-a-self-signed-code-certificate-for-xcode/).

Then, simply run `./scripts/rebuild.sh` for more streamlined builds.

## Contributing to the core app or LuaSkin
This is generally very simple in terms of the workflow, but there's less likely to be any reason to work on the core app:

* Clone our GitHub [repository](https://github.com/Hammerspoon/hammerspoon)
* Open `Hammerspoon.xcworkspace` in Xcode (Note that you'll generally need the latest available version of Xcode)
* Make the changes you want
* Push them up to a fork on GitHub
* Propose a Pull Request on GitHub
* Talk to us in #hammerspoon on Libera if you need any guidance

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
* Talk to us in #hammerspoon on Libera if you need any guidance

### Writing a new mixed Lua/Objective-C extension ###

These extensions generally expose an OS level API for users to automate (e.g. adjusting screen brightness using IOKit).

To create such an extension:

* Clone the Hammerspoon git repository
* Create the directories/files for your extension:
  * cd into the `extensions` directory
  * Make a directory for your extension
  * Create an `init.lua` to load your Objective-C code and contain any additional Lua code. You might find it easier to provide much of your API in Lua and just provide undocumented API from Objective C that does the minimum work possible. The choice is ultimately down to you, depending on the nature of the work the extension is doing.
  * Create an `internal.m` to contain your Objective-C code. Please use the LuaSkin methods to do as much work as possible, they are well tested and in most extensions can reduce the amount of Lua C API calls to almost zero. Not all of our extensions have been fully converted to LuaSkin yet (a good example is [`hs.chooser`](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/chooser/internal.m))
  * Right click on the `extensions` group in Xcode's Project Browser and add a new sub-group for your extension, then right click on the sub-group and add your `init.lua` and `internal.m` files (and any supporting `.h`/`.c`/`.m`/etc files)
  * The files you've added will probably be made members of the Hammerspoon target. You do not want this; Select each file in the Project Browser and using the File Inspector in the Utilities pane on the right of Xcode's window, deselect them from the maim Hammerspoon target.
* Configure Xcode to build your extension and include it in the `Hammerspoon.app` bundle:
  * Click on the `Hammerspoon` workspace at the very top of the Xcode Project Browser (i.e. the bar on the left)
  * Right click on `alert` in the "project and targets list" and choose `Duplicate`, which creates `alert copy` at the bottom of the list.
  * Rename the copy and drag it to the right place in the list (alphabetically)
  * Click on the target you just created, remove hs.alert's `internal.m` from the `Compile Sources` build phase, add in the `.m` files from your new module
  * Check the `Link Binary With Libraries` section for any frameworks you need to add. Typically this will jsut mean `LuaSkin.framework`, plus any additional system frameworks you need to link against.
  * Click on the `Hammerspoon` target (not the project), and in the `Target Dependencies` build phase, add the module target you just created
  * Click the menu item Product → Scheme → Manage Schemes, find `alert copy`, rename it and move it to the right place in the list of schemes
  * Edit `scripts/copy_extensions_to_bundle.sh` and add your module name to the `HS_MODULES` section. *Note*: Some modules may also need to copy extra files into the app bundle, in which case add a "special copier" to the bottom of the script.
* Build Hammerspoon and test your extension
* Push your changes up to a fork on GitHub
* Propose a Pull Request on GitHub
* Talk to us in #hammerspoon on Libera if you need any guidance

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

### Testing

All new extensions in Hammerspoon should be landed with a test suite, and any modifications to existing extensions should add appropriate tests (which may mean creating tests, if the extension in question is not currently being fully tested).

Our test suite is driven by Xcode's `XCTest` framework, and the tests can be a mixture of Lua or Lua and Objective C - it would generally only be appropriate to have unit tests in C, and functional tests in Lua.

The best place to start is in the `Hammerspoon/Hammerspoon Tests` folder in Xcode. Here are some notes on the expected setup:

 * There should be a `.m` for each extension that is being tested, named `HSfoo.m` (where `foo` is the name of the extension).
 * `HSfoo.m` should contain the declaration and implementation of an `HSfoo` class which inherits from `HSTestCase`.
 * The `setUp` method should call `[super setUpWithRequire:@"test_foo"];` to load `test_foo.lua` from the extension's folder (i.e. `extensions/foo/`)
 * The rest of `HSfoo` should be methods named `testBar`, each of which causes some test action to take place.
 * There are some helper macros for use inside the test methods:
  * `RUN_LUA_TEST()` will cause a function from `test_foo.lua` to be run, if its name exactly matches the name of the `HSfoo` method
  * `SKIP_IN_TRAVIS()` will cause this test to be skipped when running as part of our [Travis](http://www.travis-ci.org) test runs (e.g. because the Travis VMs lack hardware/network resources required to test)

When Hammerspoon detects it is is being run by `XCTest`, it loads a special `init.lua` (`Hammerspoon/Hammerspoon Tests/init.lua`) which provides a number of helper functions, mainly related to asserting state in test functions. These functions will generate Lua errors if a test failure occurs, which will cause Xcode to report the test has failed, with an appropriate backtrace in the logs. Refer to the file for the full list of assertions, but the most useful are:

 * `assertIsEqual(expected, actual)` - Ensures that the two arguments are of the same type and value
 * `assertTrue(a)`/`assertFalse(a)` - Ensure that the argument is `true`/`false` respectively
 * `assertIsString(a)`/`assertIsNumber(a)`/`assertIsBoolean(a)`/etc - Ensure that the Lua type of a variable is correct
 * `assertIsUserdataOfType(type, a)` - Ensures that the argument is a Lua userdata object of a particular type (where the type is a string, as given to `LuaSkin` when the extension registered its libraries/objects). This is particularly useful for verifying the return values of constructor functions

When adding both the `HSfoo.m` and `test_foo.lua` files to Xcode, it is important to ensure that they do not become members of the `Hammerspoon` target. They should instead both be members of the `Hammerspoon Tests` target (`HSfoo.m` in the `Compile Sources` Build Phase, `test_foo.lua` in the `Copy Bundle Resources` Build Phase).

### Third party extension distribution

While we want to have Hammerspoon shipping as many useful extensions as possible, there may be reasons for you to ship your extension separately. It would probably be easier to do this in binary form, following the init.lua/internal.so form that Hammerspoon uses, then users can just download your extension into `~/.hammerspoon/<YOUR_EXTENSION_NAME>/`.

If you do choose this route, please list your extension at [https://github.com/Hammerspoon/hammerspoon/wiki/Third-Party-Extensions](https://github.com/Hammerspoon/hammerspoon/wiki/Third-Party-Extensions) so users can discover it easily.
