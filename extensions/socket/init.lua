--- === hs.socket ===
---
--- Talk to custom protocols using asynchronous sockets

local socket = require("hs.socket.internal")

--- hs.socket.server(port[, fn]) -> hs.socket object
--- Constructor
--- Creates and binds an `hs.socket` instance to a port for listening to 0 or more clients
---
--- Parameters:
---  * port - A port number [1024-65535]. Ports [1-1023] are privileged
---  * fn - An optional callback function accepting a single parameter to process data. Can be set with the `setCallback` method
---
--- Returns:
---  * The `hs.socket` object
---
socket.server = function(port, callback)
    return socket.new(nil, port, callback)
end

return socket
