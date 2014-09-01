## Usage

1. Download [the latest release](https://github.com/mjolnir-io/mjolnir/releases/latest), unzip, right-click `Mjolnir.app`, choose "Open"

2. Install Lua 5.2 into /usr/local e.g. from Homebrew, and then install LuaRocks for Lua 5.2:

   ~~~bash
   $ brew install homebrew/versions/lua52
   $ brew install luarocks --with-lua52
   $ luarocks install --server=http://rocks.moonscript.org moonrocks
   ~~~

3. Install some modules from the readme of [mjolnir-core](https://github.com/mjolnir-io/mjolnir-core):

   ~~~bash
   $ moonrocks install mjolnir-hotkey
   $ moonrocks install mjolnir-application
   ~~~

   Note: you don't need to install every module, since some of them have lower-level ones as dependencies, e.g. installing mjolnir-hotkey automatically installs mjolnir-keycodes, etc.

4. Create `~/.mjolnir/init.lua`, and at the top, require the modules you installed, e.g. like this:

   ~~~lua
   mj.application = require "mj.application"
   mj.window = require "mj.window"
   mj.hotkey = require "mj.hotkey"
   mj.fnutils = require "mj.fnutils"
   ~~~

5. Start writing some fun stuff!

   ~~~lua
   mj.hotkey.bind({"cmd", "alt", "ctrl"}, "D", function()
      local win = mj.window.focusedwindow()
      local f = win:frame()
      f.x += 10
      win:setframe(f)
   end)
   ~~~
