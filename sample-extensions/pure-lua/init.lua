--- === hs.foobar ===
---
--- In-line documentation for your module should use three dash comments

-- Create the module's table
local foobar = {}

-- If your module depends on other hammerspoon modules, require them into locals like this:
local application = require "hs.application"

-- Internal functions you don't want to expose can be named however you like
function do_something_helpful(a)
    return a
end

-- Functions you wish to expose to users should be added to your module's table

--- hs.foobar.subtractnumbers(a, b) -> int
--- Function
--- Subtracts two numbers
function foobar.subtractnumbers(a, b)
    return a - b
end

-- Always return your top-level module; never set globals.
return foobar
