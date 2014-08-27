# Mjolnir

<img src="https://raw.githubusercontent.com/mjolnir-io/mjolnir/master/Mjolnir/Images.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Mjolnir logo" title="Mjolnir logo" align="right"/>

*Lightweight automation and productivity power-tool for OS X*

[![Build Status](https://travis-ci.org/mjolnir-io/mjolnir.svg?branch=master)](https://travis-ci.org/mjolnir-io/mjolnir)

* Current version:  Mjolnir **0.1**
* Requires:         OS X 10.8 or higher
* Download:         https://github.com/mjolnir-io/mjolnir/releases

## What is Mjolnir?

Mjolnir is an app that lets you automate common tasks using the
language Lua and pluggable extensions. At its core, this is all it
does; all the power lies in the extensions that you can install.

You use Lua and the extensions in your "config", which just means the
Lua file `~/.mjolnir/init.lua`. This file has full access to the
built-in `core` module and all Mjolnir extensions that are installed.

Some extensions that you might want to install are `core.window`,
`core.hotkey`, and `core.application`. But there are plenty more, and
there's really no limit to what an extension can do.

Mjolnir uses the very fine [Dash](http://kapeli.com/dash) app for all
its documentation, which you can install from within Dash. (To install
it, open Dash's Preferences window, go to the Downloads tab, click the
User Contributed section on the left, search for Mjolnir, and click
Install.) Then read Mjolnir's index page to get started. You'll also
find documentation for all available extensions within Mjolnir's Dash
docset.

## Extensions

The `core` extensions (those that match the pattern `core.*`) are
developed by the same author as Mjolnir (see the credits below) and
adhere to the same principles and minimalist philosophy.

But anyone is free to send pull requests for their own extensions,
which will be considered for inclusion into Mjolnir's extensions
repository. If merged, it will be available for everyone to install
from the Extensions tab.

If you're interested in contributing an extension, consult the file
[CONTRIBUTING.md](CONTRIBUTING.md).

## Principles

Development of Mjolnir.app and the extensions under the `core`
namespace follow these principles:

1. Mjolnir and the `core` extensions must be stable. It should never
   crash. You should only ever have to launch it once, and it should
   stay running until you quit. Period.

2. Mjolnir and the `core` extensions must be lightweight. They should
   never do anything that drains your computer's battery. They should
   never poll for anything. They should use as little RAM as
   possible. Everything they do should feel instant and snappy, never
   sluggish or delayed.

3. A `core` extension should be completely transparent. There should
   be no surprises in how it's behaving, or what's being executed and
   when. It should be fully predictable.

4. A `core` extension must not be bloated. Functionality should be
   included only if it can't be done in Lua or if it's extremely
   common and likely to be used by the vast majority of users. Any
   convenience functionality should go in a non-`core` namespace.

## FAQ

1. **How is Mjolnir related to Hydra, Phoenix, or Zephyros?**

   The short of it is, Mjolnir is the successor to these older apps. Or check out [the full story](http://sdegutis.github.io/2014/08/11/the-history-and-current-state-of-appgrid-zephyros-phoenix-hydra-penknife-and-mjolnir/).

3. **How does Mjolnir compare to Slate?**

   They're both programmer-centric with mostly similar goals. Look
   over their APIs and see which one suits you better.

4. **How does Mjolnir compare to Spectacle, Moom, SizeUp, Divvy, etc?**

   Mjolnir is intended for programmers who want to write programs that
   customize their environment. It's not intended to be a drag-n-drop
   solution; it's meant to allow you to write your own personalized
   productivity enhancement suite to keep and use long-term.

## Community

Our [mailing list](https://groups.google.com/forum/#!forum/mjolnir-io)
is a fine place to discuss upcoming features and extensions, find out
about new extensions, discuss existing extensions, ask questions about
how people are using Mjolnir, and share your cool ideas. We also have
a growing IRC channel on freenode, #mjolnir.

## Credits

Mjolnir is developed by Steven Degutis with the help of
[various contributors](https://github.com/mjolnir-io/mjolnir/graphs/contributors).

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
