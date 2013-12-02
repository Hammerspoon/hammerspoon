## About Phoenix

*The lightweight OS X window manager for hackers*

* Current version: **1.0**
* Requires: OS X 10.9 and up

#### Install

* Download [Zephyros-LATEST.app.tar.gz](https://raw.github.com/sdegutis/zephyros/master/Builds/Zephyros-LATEST.app.tar.gz), unzip, right-click app, choose "Open"

#### Usage

Create `~/.phoenix.js`. Then add stuff like this in it:

```javascript
api.bind('E', ['cmd'], function() {
  var win = Window.focusedWindow();
  var frame = win.frame();
  frame.x += 10;
  frame.height -= 10;
  win.setFrame(frame);
  return true;
});
```

For more ideas, see [the author's config](https://gist.github.com/sdegutis/7756583).

Note: Phoenix can only be scripted in JavaScript.

#### Current status

Perfectly usable. What's left:

- In-app upgrade
- Way better API (the current one is just a quick port of Zephyros)
- API docs (they're totally MIA)

#### Future plans

- Get [Beowulf](https://github.com/sdegutis/beowulf) up to par, and fork Phoenix to use that instead of JavaScript.

#### License

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
