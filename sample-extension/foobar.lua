local foobar = require "hs.yourid.foobar.internal"
-- If you don't have a C or Objective-C submodule, the above line gets simpler:
-- local foobar = {}

-- If your module depends on other hammerspoon modules, require them into locals like this:
local application = require "hs.application"

-- Simple functions that can be defined in Lua, should be defined in Lua:
function foobar.subtractnumbers(a, b)
  return a - b
end

-- Always return your top-level module; never set globals.
return foobar
