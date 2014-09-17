# Mjolnir

<img src="https://raw.githubusercontent.com/sdegutis/mjolnir/master/Mjolnir/Images.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Mjolnir logo" title="Mjolnir logo" align="right"/>

*Lightweight automation and productivity power-tool for OS X*

* Current version:  Mjolnir 0.4.3
* Requires:         OS X 10.8 or higher

## What is Mjolnir?

Mjolnir is an OS X app that lets you automate common tasks using the
language Lua. At its core, it doesn't actually do anything besides
load up a Lua environment; the real power lies in all the useful
modules that you can install.

You write a "config", which just means `~/.mjolnir/init.lua`. This
file, along with whatever modules it requires, have full access to the
built-in `mjolnir` module, and all Lua modules that you have installed
(e.g. from LuaRocks or any way you want to install them).

## Try it out

1. Download [the latest release](https://github.com/sdegutis/mjolnir/releases/latest), unzip, right-click `Mjolnir.app`, choose "Open"

2. Install Lua 5.2 into /usr/local e.g. from [Homebrew](http://brew.sh/), and then install LuaRocks for Lua 5.2:

   ~~~bash
   $ brew install lua
   $ brew install luarocks
   $ echo 'rocks_servers = { "http://rocks.moonscript.org" }' > ~/.luarocks/config.lua
   ~~~

3. Install some modules from this list: https://rocks.moonscript.org/search?q=mjolnir

   ~~~bash
   $ luarocks install mjolnir.hotkey
   $ luarocks install mjolnir.application
   ~~~

   Note: you don't need to install every module, since some of them have lower-level ones as dependencies, e.g. installing mjolnir-hotkey automatically installs mjolnir-keycodes, etc.

4. Create `~/.mjolnir/init.lua`, and at the top, require the modules you installed, e.g. like this:

   ~~~lua
   local application = require "mjolnir.application"
   local hotkey = require "mjolnir.hotkey"
   local window = require "mjolnir.window"
   local fnutils = require "mjolnir.fnutils"
   ~~~

   NOTE: The `mjolnir.window` module comes with `mjolnir.application`,
         so you don't need to (and can't) install it separately. Also,
         `mjolnir.fnutils` is already installed as a dependency of the
         other modules, so you don't need to explicitly install it.

5. Start writing some fun stuff!

   ~~~lua
   hotkey.bind({"cmd", "alt", "ctrl"}, "D", function()
      local win = window.focusedwindow()
      local f = win:frame()
      f.x = f.x + 10
      win:setframe(f)
   end)
   ~~~

## Uninstalling

If for any reason you want to undo everything in the above steps, do:

~~~bash
$ luarocks purge --tree=/usr/local
$ brew uninstall lua luarocks
$ rm ~/.luarocks/config.lua
~~~

## Installing to $HOME

If you run `luarocks --local install ...` instead of `luarocks
install ...`, it will install to `~/.luarocks/` instead of
`/usr/local`. Update your `package.path` and `package.cpath`
accordingly, as noted in the FAQ.

## Finding modules

Check out https://rocks.moonscript.org/search?q=mjolnir for a list of
published Mjolnir modules.

Notable modules:

- `mjolnir.hotkey` for creating global hotkeys
- `mjolnir.application` for inspecting and manipulating running OS X applications and windows
- `mjolnir.alert` for showing on-screen messages

## Documentation

Mjolnir and mjolnir-modules use [Dash](http://kapeli.com/dash) for
documentation. You can install Mjolnir's docset from the User
Contributed section of the Downloads tab in Dash's Preferences
window. It should generally update on its own.

## Publishing modules

Wrote an awesome module, and want to share with the world? Check out
the `sample-plugin` subdirectory.

When it's published, please announce it on our mailing list :)

## Principles

Development of Mjolnir.app and the core Mjolnir modules follow these
principles:

1. They must be stable. The app should never crash. You should only
   ever have to launch it once, and it should stay running until you
   quit. Period.

2. They must be lightweight. They should never do anything that drains
   your computer's battery. They should never poll for anything. They
   should use as little RAM as possible. Everything they do should
   feel instant and snappy, never sluggish or delayed.

3. They should be completely transparent. There should be no surprises
   in how it's behaving, or what's being executed and when. Everything
   should be fully predictable.

4. They must not be bloated. The app and core modules must always
   adhere to the minimalist philosophy, no excuses. Everything else
   can be a separate Lua module.

## FAQ

1. **Does LuaRocks have a way to upgrade modules automatically?**

   Sadly no. But it can be done manually by removing a module and
   re-installing it. I'm hoping maybe one day some enthusiastic
   Mjolnir users can jump in and improve the tooling around this. ;)

2. **I'm getting an error like this: "attempt to index field 'win' (a nil value)"**

   Disable and re-enable accessibility. It may look enabled, but do it
   anyway. (This is an OS X bug, not a Mjolnir bug.)

3. **I don't have things in /usr/local, so I can't load modules!**

   Add the path to `package.path` and `package.cpath` in your
   init-file. For example, if you're using Boxen, add this:

   ~~~lua
   package.path = package.path .. ';/opt/boxen/homebrew/share/lua/5.2/?.lua'
   package.cpath = package.cpath .. ';/opt/boxen/homebrew/lib/lua/5.2/?.so'
   ~~~

## Mjolnir vs. other apps

1. **Hydra, Phoenix, or Zephyros?**

   The short of it is, Mjolnir is the successor to these older apps of mine. Or check out [the full story](http://sdegutis.github.io/2014/08/11/the-history-and-current-state-of-appgrid-zephyros-phoenix-hydra-penknife-and-mjolnir/).

2. **Slate**

   They're both programmer-centric with somewhat similar goals but
   different approaches. Mjolnir is more modularized, Slate is more
   all-in-one. Try them both and see which one suits you better.

3. **Spectacle, Moom, SizeUp, Divvy**

   Mjolnir is intended for programmers who want to write programs that
   customize their environment. It's not intended to be a drag-n-drop
   solution; it's meant to allow you to write your own personalized
   productivity enhancement suite to keep and to use long-term.

## Upgrading from Hydra

Only the core modules have been ported over. I'll be porting over the
non-core modules over the next few days, so keep an eye out for
them. You may also want to sign up for the mailing list (see below) to
hear announcements of ported Hydra modules.

## Community

Our [mailing list](https://groups.google.com/forum/#!forum/mjolnir-io)
is a fine place to share ideas, and follow releases and announcements.

We also have a growing IRC channel on freenode, #mjolnir.

## Credits and Thanks

Mjolnir is developed by Steven Degutis with the help of
[various contributors](https://github.com/sdegutis/mjolnir/graphs/contributors).

Special thanks, in no special order:

- @Habbie for his constant help and support ever since the moment I
  first jumped into #lua and said "anyone wanna try out an OS X window
  manager scriptable in Lua?" and being the first person to join our
  IRC channel and for helping with nearly every Lua question I had

- @cmsj, @Keithbsmiley, @BrianGilbert, @muescha, @chdiza, @asmagill,
  @splintax, @arxanas, and @DomT4 for all their help and support

- @jasonm23 for writing, not one, not two, but *three* app icons for
  this project

- @jhgg for contributing so many awesome modules to the project

- @kapeli for his patience with my constant Dash questions and PRs

- Everyone else who has helped who I've probably forgotten: thanks for
  all your help!

- Everyone who has donated: thank you so much for your support!

See the in-app About panel for the open source licenses for the
software Mjolnir uses internally (basically just Lua's license).

## Changes

**NOTE:** When upgrading, System Preferences will *pretend* like
  Mjolnir's accessibility is enabled, showing a checked checkbox. But
  in fact, you'll still need to be disable and re-enable it. This is a
  bug in OS X.

### 0.4.3

- Removed donation requests

### 0.4.{0,1,2}

- Default implementation of `mjolnir.showerror(err)` now opens the console and focuses Mjolnir
- There's a new variable, `mjolnir.configdir = "~/.mjolnir/"` for users and modules to coordinate
- New `mjolnir.focus()` function to make Mjolnir the focused app
- The original `print` function is now stored in `mjolnir.rawprint` (rather than `mjolnir.print`, to disambiguate it)
- New `mjolnir.openconsole()` function to open console (and bring Mjolnir to front)

### 0.3.1

- Renamed global `mj` to `mjolnir`

### 0.3

- The UI has changed drastically. Expect nothing to be in the same
  place or look the same. Pretend it's a brand new app.
- Modules are now handled by LuaRocks instead of by the app itself.
- The "core" namespace has been renamed to "mj".
- The 'mj.window' module now ships with the 'mj.application' LuaRocks
  package since they depend on each other.
- `mj.screen:frame_without_dock_or_menu()` is now called `mj.screen:frame()`
- `mj.screen:frame_including_dock_and_menu()` is now called `mj.screen:fullframe()`

### 0.2

- Did anyone actually use this?

### 0.1

- First public release

## License

> Released under MIT license.
>
> Copyright (c) 2014 Steven Degutis
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
> THE SOFTWARE.
