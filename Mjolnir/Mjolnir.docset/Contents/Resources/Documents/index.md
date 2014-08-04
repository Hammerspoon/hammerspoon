### Project links

Resource                 | Link
-------------------------|------------------------------------------
Fancy Website            | http://hackhydra.com/
Github page              | https://github.com/sdegutis/hydra/
Hydra API                | http://hackhydra.com/docs/
Lua API                  | http://www.lua.org/manual/5.2/#functions
Third Party Extensions   | https://github.com/sdegutis/hydra-ext
Community Resources      | https://github.com/sdegutis/hydra/wiki
Bug Reports              | https://github.com/sdegutis/hydra/issues
Feature Requests         | https://github.com/sdegutis/hydra/issues
General Discussion       | https://github.com/sdegutis/hydra/issues
IRC channel              | #hackhydra on freenode


### Some definitions

Your "config" means your `~/.hydra/init.lua` file, and more generally anything it does. The directory `~/.hydra/` is automatically on your require-path, so you can require other files with `require` or the helpful functions in the `hydra` module.

When we say a function returns a `window` or `hotkey` or basically any non-Lua type, we really mean it returns a Lua table that represents these things. You're free to set any keys on it that you please. The only rule is that Hydra is free to store keys on them that start with an underscore for its internals, so avoid using an underscore in your key names.

Much of the Hydra API takes a few geometrical types, like `point`, `size`, and `rect`. These are just tables. Points have keys x and y, sizes have keys w and h, and rects have all four keys. So you could use a rect where a point or size is needed if you wanted.


### The REPL

First and foremost is the `repl` module, which is great for exploring and experimenting with Hydra's API. It's very similar to the terminal, having readline-like functionality built-in.


### A note about modularization

If you only have `~/.hydra/init.lua`, you can skip this section. But if you want to extract code into new files under `~/.hydra/` or put extensions there, there's a bit you should know first:

The directory `~/.hydra/` is on the require-path, so if you do `require "grid"` then it will look for `~/.hydra/grid.lua` and load it if found.


### Caching

But `require` caches its modules by name, so requiring the same module twice will do nothing!

~~~lua
require "grid" -- caches "grid" module
~~~

If you don't want caching behavior, you have two choices:

Delete the module name from the built-in table `package.loaded` after the `require`:

~~~lua
require "grid"
package.loaded["grid"] = nil
-- allows "grid" to be required again
~~~

Or use `dofile` instead:

~~~lua
dofile(package.searchpath("grid", package.path))
-- just like require, but doesn't cache "grid" module
~~~

### Where to begin

Since this is primarily a window manager, you'll probably want to look at the `window` and `hotkey` modules first. Even using just these two modules, you could make a very useful config.

But to make your config a little more full-featured, look into the `menu`, `autolaunch`, `pathwatcher`, `updates`, and `notify` modules. At the very least, the `menu` module is handy for knowing at a glance whether Hydra is running or not.

When using the `window` module, you may find that you need a window's application; look in the `application` module for what they can do.

Windows also belong to a screen, which is represented by the `screen` module. You'll find Hydra's coordinate system detailed there.

The `settings` module is there for when you need to store and retrieve Lua values between launches of Hydra (e.g. when you restart your computer).

The `hydra` module has a few functions that don't really belong in any other module. It's worth a peek.

The `timer` module is generally useful, for running one-off delayed functions, or running a function regularly at an interval.

If you're into functional programming, check out the `fnutils` module for things like map, reduce, filter, etc.

The `textgrid` module is perfect for almost any custom GUI task, such as one-off dialog boxes, list choosers, displaying documentation, having a readline-like REPL (see the `repl` module), window hints, really almost anything. It's a bit low-level, but I suspect we'll start seeing higher-level wrapper APIs for common tasks soon.

The `mouse` module is excellent for getting and setting the position of the mouse; in an upcoming version, it will also have a callback system for when the mouse has moved.

The `geometry` and `utf8` modules are just there for convenience. You may never need them.

If you want to read a scrollback of your errors, the `logger` module stores all printed information, and comes with a custom textgrid that displays it conveniently for you.

You probably won't ever need to touch the `json`, but it's there in case you need to. Hydra's internals use it for its documentation system.

Check out the sample configs to see many of these modules in action.


### Sample config

Take a look through [the official sample init](https://github.com/sdegutis/hydra/blob/master/Hydra/Bootstrapping/sample_init.lua) to see a real-world example of a Hydra config. This is the same config that Hydra presents at your first launch as one you might want to try starting with.


### Third party modules

The wiki is the definitive location for third party modules.

Third party modules are encouraged to reside under `ext`.


### Executing commands externally

You can also use the command line utility `hydra-cli` ([github page](https://github.com/sdegutis/hydra-cli)) to execute Lua code inside Hydra from the command line. You can download a precompiled binary from the github page's Releases section. Alternatively, once someone adds this to homebrew, you'll also be able to install it via `brew install hydra-cli`.
