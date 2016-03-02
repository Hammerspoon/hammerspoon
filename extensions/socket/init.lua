--- === hs.socket ===
---
--- Talk to custom protocols using asynchronous sockets

local socket = require("hs.socket.internal")


--- hs.socket.local(port, [fn]) -> hs.socket object
--- Constructor
--- Creates an asynchronous TCP socket on 'localhost' for reading (with callbacks) and writing 
---
--- Parameters:
---  * port - A port number [1024-65535]. Ports [1-1023] are privileged.
---  * fn - An optional callback function needed to read data. Can be set with `:setCallback`.
---
--- Returns:
---  * An `hs.socket` object
---
--- Notes:
socket.localhost = function(port, callback)
    return socket.new("localhost", port, callback)
end












return socket
