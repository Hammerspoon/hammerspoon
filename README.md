# Mjolnir

*Lightweight automation and productivity power-tool for OS X*

[![Build Status](https://travis-ci.org/mjolnir-io/mjolnir.svg?branch=master)](https://travis-ci.org/mjolnir-io/mjolnir)

* Current version: **0.1**
* Requires: OS X 10.8 and up
* Download: [not yet available; still in early development]
* Mailing list: https://groups.google.com/forum/#!forum/mjolnir-io

## What is Mjolnir?

Mjolnir is an app that lets you automate common tasks using the
language Lua and pluggable extensions. At its core, this is all it
does; all the power lies in the extensions that you can install.

Some extensions that you might want to install are `core.window`,
`core.hotkey`, and `core.application`. But there are plenty more, and
there's really no limit to what an extension can do.

## Extensions

The `core` extensions (those that match the pattern `core.*`) are
developed by the same author as Mjolnir (see the credits below).

But anyone is free to send pull requests for their own extensions,
which will be considered for inclusion into Mjolnir's extensions
repository. If merged, it will be available for everyone to install.

If you're interested in contributing an extension, see the file
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

## Resources

Resource                 | Link
-------------------------|------------------------------------------
Fancy Website            | http://mjolnir.io/
Github page              | https://github.com/mjolnir-io/mjolnir/
IRC channel              | #penknife on freenode (yeah, it's not a typo; sorry about that)
Mailing list             | https://groups.google.com/forum/#!forum/mjolnir-io

## FAQ

1. **How is Mjolnir related to Hydra?**

   1. Hydra has been renamed to Mjolnir (due to trademark infringement issues)
   2. Nearly all of Hydra's modules have been extracted out into opt-in extensions
   3. Extensions can now be updated at their own rate, independent of Mjolnir releases
   4. A minimal GUI has been added to make Mjolnir more convenient to use
   5. Most Mjolnir modules will be almost identical to their Hydra counterparts
   6. Your configs will still work, but consult the changelogs as you install each extension
   7. APIs for controlling Hydra's GUI have been removed in favor of the new minimal built-in GUI

   Besides these (mostly superficial) changes, Mjolnir is basically still Hydra.

1. **I'm getting an error like this: attempt to index local 'win' (a nil value)**

   It almost definitely means you need to enable accessibility. This
   is especially true after upgrading to a new version of Mjolnir, since
   the accessibility checkbox for Mjolnir may be checked; just uncheck
   it and re-check it anyway, and then it should be fixed.

2. **How does Mjolnir compare to Phoenix, or Zephyros?**

   Mjolnir is the successor to Phoenix, or Zephyros, my older
   projects which I don't update anymore. Mjolnir is more modular,
   simpler, and more efficient (see the Principles section above).

3. **How does Mjolnir compare to Slate?**

   They're both programmer-centric with mostly similar goals. Look
   over their APIs and see which one suits you better.

4. **How does Mjolnir compare to Spectacle, Moom, SizeUp, Divvy, etc?**

   Mjolnir is intended for programmers who want to write programs that
   customize their environment. It's not intended to be a drag-n-drop
   solution; it's meant to allow you to write your own personalized
   productivity enhancement suite to keep and use long-term.

5. **Can you add ____ feature?**

   Maybe. [File an issue](https://github.com/mjolnir-io/mjolnir/issues/new)
   and we'll find out!


## Credits

Mjolnir is developed by Steven Degutis with the help of
[various contributors](https://github.com/mjolnir-io/mjolnir/graphs/contributors). The
icon/logo/statusitem was created by Jason Milkins
([@jasonm23](https://github.com/jasonm23)) with additional ideas and
contributions from John Mercouris
([@jmercouris](https://github.com/jmercouris)) and is exclusively
licenced to Steven Degutis and the Mjolnir.app project.

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
