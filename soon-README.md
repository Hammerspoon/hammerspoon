# Hydra

*Hack your OS X desktop environment*

Hydra is a lightweight window manager with a powerful API and an extremely small footprint.

### Install

Downloads are in the Releases link above.

### Usage

Create `~/.hydra/init.lua`. Then add stuff like this in it:

~~~lua
api.alert("Hydra started!")

api.hotkey.bind({"cmd"}, "E", function()
    local win = api.window.focusedwindow()
    local frame = win:frame()
    frame.x = frame.x + 10
    frame.h = frame.h - 10
    win:setframe(frame)
end)
~~~

Or just run the app and it'll give you more ideas.

* For more ideas, read other people's configs [in the wiki](https://github.com/sdegutis/Hydra/wiki).

### Documentation

- [Hydra 1.0 API](https://github.com/sdegutis/Hydra/wiki/Hydra-1.0-API)

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
