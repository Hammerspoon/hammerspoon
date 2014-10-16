-- Lua and Objective-C mixed modules can have a very simple init.lua
-- All it needs to do is cause Hammerspoon to load internal.so and return
-- that object.
--
-- Alternatively, you can supply additional Lua functions on top of the 
-- Objective-C ones, by simply adding them to the module's namespace, as
-- shown in the pure-lua sample extension.
local foobar = require("hs.foobar.internal")
return foobar
