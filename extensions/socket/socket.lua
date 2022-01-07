--- === hs.socket ===
---
--- Talk to custom protocols using asynchronous TCP sockets
---
--- For UDP sockets see [`hs.socket.udp`](./hs.socket.udp.html)
---
--- `hs.socket` is implemented with [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket). CocoaAsyncSocket's [tagging features](https://github.com/robbiehanson/CocoaAsyncSocket/wiki/Intro_GCDAsyncSocket#reading--writing) provide a handy way to implement custom protocols.
---
--- For example, you can easily implement a basic HTTP client as follows (though using [`hs.http`](./hs.http.html) is recommended for the real world):
---
--- <pre style="font-size:10px">
--- local TAG_HTTP_HEADER, TAG_HTTP_CONTENT = 1, 2
--- local body = ""
--- local function httpCallback(data, tag)
---   if tag == TAG_HTTP_HEADER then
---     print(tag, "TAG_HTTP_HEADER"); print(data)
---     local contentLength = data:match("\r\nContent%-Length: (%d+)\r\n")
---     client:read(tonumber(contentLength), TAG_HTTP_CONTENT)
---   elseif tag == TAG_HTTP_CONTENT then
---     print(tag, "TAG_HTTP_CONTENT"); print(data)
---     body = data
---   end
--- end
---
--- client = hs.socket.new(httpCallback):connect("google.com", 80)
--- client:write("GET /index.html HTTP/1.0\r\nHost: google.com\r\n\r\n")
--- client:read("\r\n\r\n", TAG_HTTP_HEADER)
--- </pre>
---
--- Resulting in the following console output (adjust log verbosity with `hs.socket.setLogLevel()`) :
---
--- <pre style="font-size:10px">
---             LuaSkin: (secondary thread): TCP socket connected
---             LuaSkin: (secondary thread): Data written to TCP socket
---             LuaSkin: (secondary thread): Data read from TCP socket
--- 1 TAG_HTTP_HEADER
--- HTTP/1.0 301 Moved Permanently
--- Location: http://www.google.com/index.html
--- Content-Type: text/html; charset=UTF-8
--- Date: Thu, 03 Mar 2016 08:38:02 GMT
--- Expires: Sat, 02 Apr 2016 08:38:02 GMT
--- Cache-Control: public, max-age=2592000
--- Server: gws
--- Content-Length: 229
--- X-XSS-Protection: 1; mode=block
--- X-Frame-Options: SAMEORIGIN
---
---             LuaSkin: (secondary thread): Data read from TCP socket
--- 2 TAG_HTTP_CONTENT
--- &lt;HTML&gt;&lt;HEAD&gt;&lt;meta http-equiv=&quot;content-type&quot; content=&quot;text/html;charset=utf-8&quot;&gt;
--- &lt;TITLE&gt;301 Moved&lt;/TITLE&gt;&lt;/HEAD&gt;&lt;BODY&gt;
--- &lt;H1&gt;301 Moved&lt;/H1&gt;
--- The document has moved
--- &lt;A HREF=&quot;http://www.google.com/index.html&quot;&gt;here&lt;/A&gt;.
--- &lt;/BODY&gt;&lt;/HTML&gt;
---             LuaSkin: (secondary thread): TCP socket disconnected Socket closed by remote peer
--- </pre>
---
---


--- === hs.socket.udp ===
---
--- Talk to custom protocols using asynchronous UDP sockets
---
--- For TCP sockets see [`hs.socket`](./hs.socket.html)
---
--- You can do a lot of neat trivial and non-trivial things with these. A simple ping ponger:
--- <pre style="font-size:10px">
--- function ping(data, addr)
---   print(data)
---   addr = hs.socket.parseAddress(addr)
---   hs.timer.doAfter(1, function()
---     client:send("ping", addr.host, addr.port)
---   end)
--- end
---
--- function pong(data, addr)
---   print(data)
---   addr = hs.socket.parseAddress(addr)
---   hs.timer.doAfter(1, function()
---     server:send("pong", addr.host, addr.port)
---   end)
--- end
---
--- server = hs.socket.udp.server(9001, pong):receive()
--- client = hs.socket.udp.new(ping):send("ping", "localhost", 9001):receive()
--- </pre>
--- Resulting in the following endless exchange:
--- <pre style="font-size:10px">
--- 20:26:56    LuaSkin: (secondary thread): Data written to UDP socket
---             LuaSkin: (secondary thread): Data read from UDP socket
--- ping
--- 20:26:57    LuaSkin: (secondary thread): Data written to UDP socket
---             LuaSkin: (secondary thread): Data read from UDP socket
--- pong
--- 20:26:58    LuaSkin: (secondary thread): Data written to UDP socket
---             LuaSkin: (secondary thread): Data read from UDP socket
--- ping
--- 20:26:59    LuaSkin: (secondary thread): Data written to UDP socket
---             LuaSkin: (secondary thread): Data read from UDP socket
--- pong
--- ...
--- </pre>
---
--- You can do some silly things with a callback factory and enabling broadcasting:
--- <pre style="font-size:10px">
--- local function callbackMaker(name)
---   local fun = function(data, addr)
---     addr = hs.socket.parseAddress(addr)
---     print(name.." received data:\n"..data.."\nfrom host: "..addr.host.." port: "..addr.port)
---   end
---   return fun
--- end
---
--- local listeners = {}
--- local port = 9001
---
--- for i=1,3 do
---   table.insert(listeners, hs.socket.udp.new(callbackMaker("listener "..i)):reusePort():listen(port):receive())
--- end
---
--- broadcaster = hs.socket.udp.new():broadcast()
--- broadcaster:send("hello!", "255.255.255.255", port)
--- </pre>
--- Since neither IPv4 nor IPv6 have been disabled, the broadcast is received on both protocols ('dual-stack' IPv6 addresses shown):
--- <pre style="font-size:10px">
--- listener 2 received data:
--- hello!
--- from host: ::ffff:192.168.0.3 port: 53057
--- listener 1 received data:
--- hello!
--- from host: ::ffff:192.168.0.3 port: 53057
--- listener 3 received data:
--- hello!
--- from host: ::ffff:192.168.0.3 port: 53057
--- listener 1 received data:
--- hello!
--- from host: 192.168.0.3 port: 53057
--- listener 3 received data:
--- hello!
--- from host: 192.168.0.3 port: 53057
--- listener 2 received data:
--- hello!
--- from host: 192.168.0.3 port: 53057
--- </pre>
---

-- module implementation --------------------------------

local module = require("hs.libsocket")
module.udp = require("hs.libsocketudp")

local tcpSocketObject = hs.getObjectMetatable("hs.socket")
local udpSocketObject = hs.getObjectMetatable("hs.socket.udp")

local log=hs.luaSkinLog
module.setLogLevel=log.setLogLevel
module.getLogLevel=log.getLogLevel


--- hs.socket.timeout
--- Variable
--- Timeout for the socket operations, in seconds. New [`hs.socket`](#new) objects will be created with this timeout value, but can individually change it with the [`setTimeout`](#setTimeout) method
---
--- If the timeout value is negative, the operations will not use a timeout. The default value is -1
---
module.timeout = -1

--- hs.socket.udp.timeout
--- Variable
--- Timeout for the socket operations, in seconds. New [`hs.socket.udp`](#new) objects will be created with this timeout value, but can individually change it with the [`setTimeout`](#setTimeout) method
---
--- If the timeout value is negative, the operations will not use a timeout. The default value is -1
---
module.udp.timeout = -1

--- hs.socket.udp.parseAddress(sockaddr) -> table or nil
--- Function
--- Alias for [`hs.socket.parseAddress`](./hs.socket.html#parseAddress)
---
module.udp.parseAddress = module.parseAddress

--- hs.socket.server(port|path[, fn]) -> hs.socket object
--- Constructor
--- Creates and binds an [`hs.socket`](#new) instance to a port or path (Unix domain socket) for listening
---
--- Parameters:
---  * port - A port number [0-65535]. Ports [1-1023] are privileged. Port 0 allows the OS to select any available port
---  * path - A string containing the path to the Unix domain socket
---  * fn - An optional [callback function](#setCallback) for reading data from the socket, settable here for convenience
---
--- Returns:
---  * An [`hs.socket`](#new) object
---
module.server = function(port, callback)
  local sock = module.new(callback)
  sock:listen(port)
  return sock
end

--- hs.socket.udp.server(port[, fn]) -> hs.socket.udp object
--- Constructor
--- Creates and binds an [`hs.socket.udp`](#new) instance to a port for listening
---
--- Parameters:
---  * port - A port number [0-65535]. Ports [1-1023] are privileged. Port 0 allows the OS to select any available port
---  * fn - An optional [callback function](#setCallback) for reading data from the socket, settable here for convenience
---
--- Returns:
---  * An [`hs.socket.udp`](#new) object
---
module.udp.server = function(port, callback)
  local sock = module.udp.new(callback)
  sock:listen(port)
  return sock
end

--- hs.socket:receive(delimiter[, tag]) -> self
--- Method
--- Alias for [`hs.socket:read`](#read)
---
tcpSocketObject.receive = tcpSocketObject.read

--- hs.socket:send(message[, tag]) -> self
--- Method
--- Alias for [`hs.socket:write`](#write)
---
tcpSocketObject.send = tcpSocketObject.write

--- hs.socket.udp:read(delimiter[, tag]) -> self
--- Method
--- Alias for [`hs.socket.udp:receive`](#receive)
---
udpSocketObject.read = udpSocketObject.receive

--- hs.socket.udp:readOne(delimiter[, tag]) -> self
--- Method
--- Alias for [`hs.socket.udp:receiveOne`](#receiveOne)
---
udpSocketObject.readOne = udpSocketObject.receiveOne

--- hs.socket.udp:write(message[, tag]) -> self
--- Method
--- Alias for [`hs.socket.udp:send`](#send)
---
udpSocketObject.write = udpSocketObject.send


return module
