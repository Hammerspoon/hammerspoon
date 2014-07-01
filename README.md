# Hydra

*Hack your OS X desktop environment*

Hydra is a lightweight window manager with a powerful API and an extremely small footprint.

### Install

Download from the [Releases](https://github.com/sdegutis/hydra/releases) page.

### Usage

Here's a sample of what you might write:

~~~lua
hydra.alert("Hydra started!")

hotkey.bind({"cmd"}, "E", function()
    local win = window.focusedwindow()
    local frame = win:frame()
    frame.x = frame.x + 10
    frame.h = frame.h - 10
    win:setframe(frame)
end)
~~~

Anyway, when you run the app, it'll give you a better sample config.

### Resources

Resource                 | Link
-------------------------|------------------------------------------
Documentation            | http://sdegutis.github.io/hydra/
Lua API                  | http://www.lua.org/manual/5.2/#functions
Community Contributions  | https://github.com/sdegutis/hydra/wiki

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
