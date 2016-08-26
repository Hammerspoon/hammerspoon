--- === hs.stdlib ===
---
--- This module provides functionality from lua-stdlib
---
--- Documentation for [`std`](https://github.com/lua-stdlib/lua-stdlib): http://lua-stdlib.github.io/lua-stdlib/
--- Documentation for [`std.functional`](https://github.com/lua-stdlib/functional): http://lua-stdlib.github.io/functional/
--- Documentation for [`std.prototype`](https://github.com/lua-stdlib/prototype): http://lua-stdlib.github.io/prototype/
--- Documentation for [`std.strict`](https://github.com/lua-stdlib/strict): http://lua-stdlib.github.io/strict/
---
--- #### Usage:
--- ~~~lua
--- std = require 'hs.stdlib'
--- table = std.table
--- 
--- k = table.keys({ a=1, b=true, c="hello" })
--- hs.inspect(k)
---  { "b", "c", "a" }
--- 
--- f = std.functional
--- m = f.map(f.lambda '=_1*_1', {1, 2, 3, 4})
--- hs.inspect(m)
---  { 1, 4, 9, 16 }
--- ~~~

local module          = require("std")
module.prototype      = require("std.prototype")
module.strict         = require("std.strict")
module.functional     = require("functional")
return module
