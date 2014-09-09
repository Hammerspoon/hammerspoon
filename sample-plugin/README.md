This is a sample project to demonstrate writing a Mjolnir plugin.

### Your module's require-path

Our sample module is called "mjolnir.yourid.foobar". This is both the
name of the module, and its require-path. It's a good practice to make
the module name and require path the same thing.

### Picking a name for your module

You should prefix your module's name with "mjolnir." followed by a
short unique identifier owned by you, e.g. maybe your initials. Don't
use "yourid", that's just here for example. For example, my grid
module is published as "mjolnir.sd.grid" where "sd" are my initials.

### Installing prerequisites

Before you begin, you'll need to install Lua 5.2, LuaRocks, and
MoonRocks. (If you have Mjolnir installed, you've probably already
done the first two.)

~~~bash
$ brew install homebrew/versions/lua52
$ brew install luarocks --with-lua52
$ luarocks install --server=http://rocks.moonscript.org moonrocks
~~~

### A note about ARC

If you're writing a module that contains any Objective-C, you'll
probably have to write it without ARC. When LuaRocks compiles your
module, it sets `CC="export MACOSX_DEPLOYMENT_TARGET=10.5; gcc"` for
some reason, and it doesn't set the `-fobjc-arc` flag. You can try to
change the build rules to fix these, but it's way more trouble than
it's worth. It's easiest to do what I do and just skip using ARC.

### Optionally create an Xcode project

If you're writing a module that has some C or Objective-C, you may
want to create a little Xcode project for it. That way, you get
autocompletion and other helpful Xcode features.

1. New Xcode Project -> Framework & Library -> C/C++ Library
2. Add `/usr/local/include` to "Header Search Paths"
3. Add `/usr/local/lib` to "Library Search Paths"
4. Add `-llua` to "Other Linker Flags"
5. Add your `.m` file to the Xcode project
6. Add `#import <lauxlib.h>` to the top of your `.m` file
7. Turn off ARC

Keep in mind that this Xcode project has literally nothing to do with
the actual binary that this will result in. LuaRocks takes care of
that on its own, with its own build script. The Xcode project is
purely here as a convenience. If you'd rather skip this whole step and
write your Objective-C code in another editor, that works too.

### Building and testing your module

LuaRocks has a helpful command to build and install the LuaRocks
module in the current directory:

~~~bash
$ luarocks make
~~~

Then, just launch Mjolnir, require your module, and test it out:

~~~lua
local foobar = require "mjolnir.yourid.foobar"
print(foobar.addnumbers(1, 2))
~~~

You can repeat this process any number of times, since I'm pretty sure
`luarocks make` will overwrite any pre-existing locally installed
module with the same name.

### Publishing your module

~~~bash
$ luarocks make
~~~

Now test it thoroughly. Make sure it actually works. Automated tests
are not enough, actually load it up in Mjolnir and use it. Preferrably
for a few days.

Then, patch a MoonRocks file as specified below.

You'll need to register an account at https://rocks.moonscript.org/
and create an API key in the Settings page for the next steps:

~~~bash
$ luarocks pack mjolnir.yourid.foobar
$ moonrocks upload --skip-pack mjolnir.yourid.foobar-0.1-1.rockspec
$ moonrocks upload mjolnir.yourid.foobar-0.1-1.macosx-x86_64.rock
~~~

Congratulations, it's now available for everyone!

### Patching the MoonRocks file

MoonRocks is almost entirely free of any Lua 5.1-specific
features. All except two lines.

So edit `/usr/local/share/lua/5.2/moonrocks/actions.lua`:

Apply this pseudo-patch manually:

~~~lua
- local fn, err = loadfile(fname)
+ local fn, err = loadfile(fname, nil, rockspec)

- setfenv(fn, rockspec)
~~~
