# Hydra

<img src="https://raw.githubusercontent.com/sdegutis/hydra/master/Hydra/XcodeCrap/Images.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Hydra logo" title="Hydra logo" align="right"/>

*Hack your OS X desktop environment*

[![Build Status](https://travis-ci.org/sdegutis/hydra.svg?branch=master)](https://travis-ci.org/sdegutis/hydra)

* Current version: **1.0**
* Requires: OS X 10.8 and up
* Download: [get latest release](https://github.com/sdegutis/hydra/releases/latest), unzip, right-click app, choose "Open"

## Usage

Hydra will look for `~/.hydra/init.lua` and run it if it exists. But
if you haven't written one yet, it will run a fallback config that
gives you a menu bar icon that contains an option to open the sample
initfile (shown below). You can save it to `~/.hydra/init.lua` to get
started with a really basic starter config.

**NOTE:** Be sure to read the [overview](http://hackhydra.com/docs/)
page of the documentation! It contains some very valuable information
for getting started which isnt' found anywhere else in this project.

## Example

When you install and run Hydra, you'll see a menu that has an option
to open the sample config, which you can then save as your own
initfile and modify. But so you can get an idea of what it looks like,
I've pasted the entire sample config here.

~~~lua
-- Hi!
-- Save this as ~/.hydra/init.lua and choose Reload Config from the menu (or press cmd-alt-ctrl R}

-- show an alert to let you know Hydra's running
hydra.alert("Hydra sample config loaded", 1.5)

-- open a repl with mash-R; requires https://github.com/sdegutis/hydra-cli
hotkey.bind({"cmd", "ctrl", "alt"}, "R", repl.open)

-- show a helpful menu
hydra.menu.show(function()
    local t = {
      {title = "Reload Config", fn = hydra.reload},
      {title = "Open REPL", fn = repl.open},
      {title = "-"},
      {title = "About Hydra", fn = hydra.showabout},
      {title = "Check for Updates...", fn = function() hydra.updates.check(nil, true) end},
      {title = "Quit", fn = os.exit},
    }

    if not hydra.license.haslicense() then
      table.insert(t, 1, {title = "Buy or Enter License...", fn = hydra.license.enter})
      table.insert(t, 2, {title = "-"})
    end

    return t
end)

-- move the window to the right half of the screen
function movewindow_righthalf()
  local win = window.focusedwindow()
  local newframe = win:screen():frame_without_dock_or_menu()
  newframe.w = newframe.w / 2
  newframe.x = newframe.x + newframe.w -- comment out this line to push it to left half of screen
  win:setframe(newframe)
end

-- bind your custom function to a convenient hotkey
-- note: it's good practice to keep hotkey-bindings separate from their functions, like we're doing here
hotkey.new({"cmd", "ctrl", "alt"}, "L", movewindow_righthalf):enable()

-- uncomment this line if you want Hydra to make sure it launches at login
-- hydra.autolaunch.set(true)

-- when the "update is available" notification is clicked, open the website
notify.register("showupdate", function() os.execute('open https://github.com/sdegutis/Hydra/releases') end)

-- check for updates every week, and also right now (when first launching)
timer.new(timer.weeks(1), hydra.updates.check):start()
hydra.updates.check()
~~~

### Using Hydra from the command line

Install [hydra-cli](https://github.com/sdegutis/hydra-cli) to access
Hydra from the command line. Then you can do things like this:

~~~bash
$ hydra
Hydra interactive prompt.
> window.focusedwindow():title()
sdegutis — hydra — 100×30
> window.focusedwindow():application():title()
Terminal
~~~

At this interactive prompt, type `help` for instructions on using the
built-in documentation system.

**NOTE:** `hydra-cli` is guaranteed to be compatible with Hydra 1.x
(and will most likely remain compatible with all future versions of
Hydra). So you can upgrade `hydra-cli` mostly independently of the
Hydra version you're using.

## Screenshots

Some brief examples of what you can do with Hydra:

| Description                                                                                                           | Animated Screenshot                                                                       |
|-----------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| Using hotkeys to move and resize a window along a grid (using [hydra-grid](https://github.com/sdegutis/hydra-grid))   | ![grid.gif](https://raw.githubusercontent.com/sdegutis/hydra/master/screenshots/grid.gif) |
| Using a hotkey to open Dictionary.app and show an alert (using `application.launchorfocus` and `hydra.alert`)         | ![dict.gif](https://raw.githubusercontent.com/sdegutis/hydra/master/screenshots/dict.gif) |
| Exploring the built-in docs                                                                                           | ![repl.gif](https://raw.githubusercontent.com/sdegutis/hydra/master/screenshots/repl.gif) |
| Using [hydra-cli](https://github.com/sdegutis/hydra-cli) to control Hydra from the command line                       | ![ipc.gif](https://raw.githubusercontent.com/sdegutis/hydra/master/screenshots/ipc.gif)   |

## Principles

1. Hydra must be stable. It should never crash. You should only ever
   have to launch it once, and it should stay running until you quit
   it. Period.

2. Hydra must be lightweight. It should never do anything that drains
   your computer's battery. It should never poll for anything. It
   should use as little RAM as possible. Everything it does should
   feel instant and snappy, never sluggish or delayed.

3. Hydra's API should be completely transparent. There should be no
   surprises in how it's behaving, or what's being executed and
   when. It should be fully predictable.

4. Hydra's API must not be bloated. Functionality should be included
   only if it can't be done in Lua or if it's extremely common and
   likely to be used by the vast majority of users.

## Resources

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

## Free and Commercial Software

Hydra is open source, released under the MIT license. But it's also
commercial, requiring you to eventually purchase a license. However,
the trial period is not timed, and doesn't remove any functionality.

## FAQ

1. **I'm getting an error like this: attempt to index local 'win' (a nil value)**

   It almost definitely means you need to enable accessibility. This
   is especially true after upgrading to a new version of Hydra, since
   the accessibility checkbox for Hydra may be checked; just uncheck
   it and re-check it anyway, and then it should be fixed.

2. **How does Hydra compare to Phoenix or Zephyros?**

   Hydra is the successor to Phoenix and Zephyros, my older projects
   which I don't update anymore. Hydra is simpler and more efficient
   (see the Principles section above).

3. **How does Hydra compare to Slate?**

   They're both programmer-centric with mostly similar goals. Look
   over their APIs and see which one suits you better.

4. **How does Hydra compare to Spectacle, Moom, SizeUp, Divvy, etc?**

   Hydra is intended for programmers who want to write programs that
   customize their environment. It's not intended to be a
   quick-and-easy solution, it's meant to allow you to write your own
   very personalized productivity enhancement suite to keep and use
   long-term.

5. **Can you add ____ feature?**

   Maybe. [File an issue](https://github.com/sdegutis/hydra/issues/new) and we'll find out!

6. **Where can I find a comprehensive and detailed list of alternatives to Hydra?**

   https://news.ycombinator.com/item?id=7982514

7. **Can I install Hydra via Cask?**

   Technically yes, but it will cause a lot of weird problems for
   you. Wait until Cask finishes their "upgrade" feature first, so
   that you can remove older copies of Hydra.app.


## Credits

### Programming

Hydra was created by Steven Degutis with the help of [various contributors](https://github.com/sdegutis/hydra/graphs/contributors).

### Artwork

<img src="https://raw.githubusercontent.com/sdegutis/hydra/master/Hydra/XcodeCrap/Images.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Hydra logo" title="Hydra logo" align="right"/>

The icon/logo/statusitem was created by Jason Milkins
([@jasonm23](https://github.com/jasonm23)) with additional ideas and
contributions from John Mercouris
([@jmercouris](https://github.com/jmercouris)). It's exclusively
licenced to Steven Degutis and the Hydra.app project.

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
