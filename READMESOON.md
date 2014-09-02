# Mjolnir

<img src="https://raw.githubusercontent.com/mjolnir-io/mjolnir/master/Mjolnir/Images.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Mjolnir logo" title="Mjolnir logo" align="right"/>

*Lightweight automation and productivity power-tool for OS X*

* Current version:  Mjolnir **0.3.1**
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

1. Download [the latest release](https://github.com/mjolnir-io/mjolnir/releases/latest), unzip, right-click `Mjolnir.app`, choose "Open"

2. Install Lua 5.2 into /usr/local e.g. from Homebrew, and then install LuaRocks for Lua 5.2:

   ~~~bash
   $ brew install homebrew/versions/lua52
   $ brew install luarocks --with-lua52
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
   mjolnir.hotkey.bind({"cmd", "alt", "ctrl"}, "D", function()
      local win = mjolnir.window.focusedwindow()
      local f = win:frame()
      f.x = f.x + 10
      win:setframe(f)
   end)
   ~~~

If for any reason you want to undo everything in the above steps, do:

~~~bash
$ luarocks purge --tree=/usr/local
$ brew uninstall lua52 luarocks
$ rm ~/.luarocks/config.lua
~~~

## Finding modules

Check out https://rocks.moonscript.org/search?q=mjolnir for a list of
published Mjolnir modules.

Especially of note are `mjolnir.hotkey` for creating global hotkeys,
and `mjolnir.application` for inspecting and manipulating running OS X
applications and windows.

If you publish a new Mjolnir module, please announce it on our mailing
list.

## Documentation

Mjolnir and mjolnir-modules use [Dash](http://kapeli.com/dash) for
documentation. You can install the Mjolnir docset from inside Dash,
under Preferences -> Downloads -> User Contributed. Then, type
`mjolnir:` to limit your search scope to Mjolnir functions.

## Writing Mjolnir plugins

Check out [this sample Mjolnir plugin](https://github.com/mjolnir-io/mjolnir-sample-plugin).

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

1. **How is Mjolnir related to Hydra, Phoenix, or Zephyros?**

   The short of it is, Mjolnir is the successor to these older apps. Or check out [the full story](http://sdegutis.github.io/2014/08/11/the-history-and-current-state-of-appgrid-zephyros-phoenix-hydra-penknife-and-mjolnir/).

2. **How does Mjolnir compare to Slate?**

   They're both programmer-centric with mostly similar goals but very
   different approaches. Try them both and see which one suits you
   better.

3. **How does Mjolnir compare to Spectacle, Moom, SizeUp, Divvy, etc?**

   Mjolnir is intended for programmers who want to write programs that
   customize their environment. It's not intended to be a drag-n-drop
   solution; it's meant to allow you to write your own personalized
   productivity enhancement suite to keep and use long-term.

## Community

Our [mailing list](https://groups.google.com/forum/#!forum/mjolnir-io)
is a fine place to share ideas, and follow releases and announcements.

We also have a growing IRC channel on freenode, #mjolnir.

## Credits

Mjolnir is developed by Steven Degutis with the help of
[various contributors](https://github.com/mjolnir-io/mjolnir/graphs/contributors).

See the About-panel in the app for other credits including open source
software Mjolnir uses.

## Changes

**NOTE:** When upgrading, System Preferences will *pretend* like
  Mjolnir's accessibility is enabled, showing a checked checkbox. But
  in fact, you'll still need to be disable and re-enable it. This is a
  bug in OS X.

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

## Donate

I've worked hard to make this app useful and easy to use. I've also
released it with a liberal open source license, so that you can do
with it as you please.

So, instead of charging for licenses, I'm asking for donations. If you
find Mjolnir genuinely beneficial to your productivity, I encourage
you to donate what you believe is fair.

Your donations will fund the time I'll be spending making Mjolnir even
better, and will be used to compensate volunteers for the time and
skills which they have generously contributed to the project.

Currently, donations can be made [by PayPal](https://www.paypal.com/cgi-bin/webscr?business=sbdegutis@gmail.com&cmd=_donations&item_name=Mjolnir.app%20donation&no_shipping=1) or [with a credit card](https://sites.fastspring.com/sdegutis/instant/hydra).

## License

> Released under MIT license.
>
> Copyright (c) 2013 Steven Degutis
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
