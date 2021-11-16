--- === hs.httpserver ===
---
--- Simple HTTP server
---
--- Notes:
---  * Running an HTTP server is potentially dangerous, you should seriously consider the security implications of exposing your Hammerspoon instance to a network - especially to the Internet
---  * As a user of Hammerspoon, you are assumed to be highly capable, and aware of the security issues

local httpserver = require "hs.libhttpserver"
httpserver.hsminweb = require "hs.httpserver_hsminweb"

return httpserver
