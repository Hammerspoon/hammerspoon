# Hydra

*Hack your OS X desktop environment*

Hydra is a lightweight window manager with a powerful API and an extremely small footprint.

### Install

Download from [Releases](https://github.com/sdegutis/hydra/releases)
page, unzip the downloaded file, and run the app.

### Usage

Hydra will look for `~/.hydra/init.lua` and run it if it exists. But
if you haven't written one yet, it will run a fallback config that
gives you a menu bar icon that contains an option to open
[this sample config](https://github.com/sdegutis/hydra/blob/master/Hydra/sample_config.lua).
You can paste that into your `~/.hydra/init.lua` to get started with a
really basic starter config.

### Example

https://github.com/sdegutis/hydra/blob/master/Hydra/sample_config.lua

Here's a snippet:
~~~lua
-- show a helpful menu
menu.show(function()
    local updatetitles = {[true] = "Install Update", [false] = "Check for Update..."}
    local updatefns = {[true] = updates.install, [false] = checkforupdates}
    local hasupdate = (updates.newversion ~= nil)

    return {
      {title = "Reload Config", fn = hydra.reload},
      {title = "-"},
      {title = "About", fn = hydra.showabout},
      {title = updatetitles[hasupdate], fn = updatefns[hasupdate]},
      {title = "Quit Hydra", fn = os.exit},
    }
end)

-- move the window to the right a bit, and make it a little shorter
hotkey.new({"cmd", "ctrl", "alt"}, "J", function()
    local win = window.focusedwindow()
    local frame = win:frame()
    frame.x = frame.x + 10
    frame.h = frame.h - 10
    win:setframe(frame)
end):enable()
~~~

### Screenshots

It doesn't really make sense to show screenshots. Most of what you do
is bind global hotkeys to functions that you write which move your
windows around on your screen. So a screenshot would look like, well,
a normal screen.

### Resources

Resource                 | Link
-------------------------|------------------------------------------
Hydra API                | http://sdegutis.github.io/hydra/
Lua API                  | http://www.lua.org/manual/5.2/#functions
Community Contributions  | https://github.com/sdegutis/hydra/wiki

### Donate

I've worked hard to make Hydra useful and easy to use. I've also
released it with a liberal open source license, so that you can do
with it as you please. So, instead of charging for licenses, I'm
asking for donations. If you find it helpful, I encourage you to
donate what you believe would have been a fair price for a license:

[Donate via PayPal](https://www.paypal.com/cgi-bin/webscr?business=sbdegutis@gmail.com&cmd=_donations&item_name=Hydra.app%20donation)

### License

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
