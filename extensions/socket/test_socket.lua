-- hs.socket tests
hs.socket = require("hs.socket")
hs.timer = require("hs.timer")
hs.fnutils = require("hs.fnutils")

require "test_udpsocket"

-- globals for async TCP tests
port = 9001
sockfile = "/tmp/sock"

callback = function(data, tag)
  readData = data
  readTag = tag
end

-- constructors
function testTcpSocketInstanceCreation()
  assertIsUserdataOfType("hs.socket", hs.socket.new())

  return success()
end

function testTcpSocketInstanceCreationWithCallback()
  assertIsUserdataOfType("hs.socket", hs.socket.new(print))

  return success()
end

function testTcpListenerSocketCreation()
  assertIsUserdataOfType("hs.socket", hs.socket.server(port))

  return success()
end

function testTcpListenerSocketCreationWithCallback()
  assertIsUserdataOfType("hs.socket", hs.socket.server(port, print))

  return success()
end

function testTcpListenerSocketAttributes()
  local server = hs.socket.server(port, print)

  local info = server:info()

  assertIsEqual("SERVER", info.userData)
  assertIsEqual("", info.unixSocketPath)
  assertIsEqual(port, info.localPort)
  assertIsEqual("0.0.0.0", info.localHost)
  assertIsEqual(0, info.connectedPort)
  assertIsEqual("", info.connectedHost)
  assertFalse(info.isDisconnected)
  assertFalse(info.isConnected)

  return success()
end

function testTcpUnixListenerSocketAttributes()
  local server = hs.socket.server(sockfile, print)

  local info = server:info()

  assertIsEqual("SERVER", info.userData)
  assertIsEqual(sockfile, info.unixSocketPath)
  assertIsEqual(0, info.localPort)
  assertIsEqual("", info.localHost)
  assertIsEqual(0, info.connectedPort)
  assertIsEqual("", info.connectedHost)
  assertFalse(info.isDisconnected)
  assertFalse(info.isConnected)

  return success()
end

-- reusing client and server sockets
function testTcpDisconnectAndReuseValues()
  if (type(serverLocalPort) == "number" and serverLocalPort == port and
      type(clientConnectedPort) == "number" and clientConnectedPort == port and
      type(serverDisconnectedPort) == "number" and serverDisconnectedPort == 0 and
      type(clientDisconnectedPort) == "number" and clientDisconnectedPort == 0 and
      type(server2LocalPort) == "number" and server2LocalPort == port and
      type(client2ConnectedPort) == "number" and client2ConnectedPort == port and
      type(server2DisconnectedPort) == "number" and server2DisconnectedPort == 0 and
      type(client2DisconnectedPort) == "number" and client2DisconnectedPort == 0) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpDisconnectAndReuse()
  server = hs.socket.server(port)
  client = hs.socket.new():connect("localhost", port, function()
    serverLocalPort = server:info().localPort
    clientConnectedPort = client:info().connectedPort

    server:disconnect()

    hs.timer.doAfter(0.1, function()
      serverDisconnectedPort = server:info().localPort
      clientDisconnectedPort = client:info().connectedPort

      client:listen(port) -- switch roles
      server:connect("localhost", port, function()
        server2LocalPort = client:info().localPort
        client2ConnectedPort = server:info().connectedPort

        client:disconnect()

        hs.timer.doAfter(0.1, function()
          server2DisconnectedPort = client:info().localPort
          client2DisconnectedPort = server:info().connectedPort
        end)
      end)
    end)
  end)

  return success()
end

-- multiple client connection counts
function testTcpConnectedValues()
  if (type(serverConnected) == "boolean" and serverConnected == true and
      type(serverConnections) == "number" and serverConnections == 3 and
      type(clientConnected) == "boolean" and clientConnected == true and
      type(clientConnections) == "number" and clientConnections == 1 and
      type(serverConnectedAfterDisconnect) == "boolean" and serverConnectedAfterDisconnect == false and
      type(serverConnectionsAfterDisconnect) == "number" and serverConnectionsAfterDisconnect == 0 and
      type(clientConnectedAfterDisconnect) == "boolean" and clientConnectedAfterDisconnect == false and
      type(clientConnectionsAfterDisconnect) == "number" and clientConnectionsAfterDisconnect == 0) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpConnected()
  local server = hs.socket.server(port)
  local client = hs.socket.new():connect("localhost", port)
  local client2 = hs.socket.new():connect("localhost", port)
  local client3 = hs.socket.new():connect("localhost", port)

  hs.timer.doAfter(0.2, function()
    serverConnected = server:connected()
    serverConnections = server:connections()
    clientConnected = client:connected()
    clientConnections = client:connections()

    server:disconnect()

    hs.timer.doAfter(0.2, function()
      serverConnectedAfterDisconnect = server:connected()
      serverConnectionsAfterDisconnect = server:connections()
      clientConnectedAfterDisconnect = client:connected()
      clientConnectionsAfterDisconnect = client:connections()
    end)
  end)

  return success()
end

-- test failure to connect already connected sockets
function testTcpAlreadyConnectedValues()
  if (type(server1Connected) == "boolean" and server1Connected == true and
      type(server1Userdata) == "string" and server1Userdata == "SERVER" and
      type(server2Connected) == "boolean" and server2Connected == false and
      type(server2Userdata) == "string" and server2Userdata == "" and
      type(clientConnectedPort) == "number" and clientConnectedPort == port and
      type(server3Connected) == "boolean" and server3Connected == true and
      type(server3Userdata) == "string" and server3Userdata == "SERVER" and
      type(server4Connected) == "boolean" and server4Connected == false and
      type(server4Userdata) == "string" and server4Userdata == "" and
      type(clientSockfile) == "string" and clientSockfile == sockfile) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpAlreadyConnected()
  server1 = hs.socket.server(port)
  server2 = hs.socket.server(port)
  client = hs.socket.new():connect("localhost", port, function()
    server1Connected = server1:connected()
    server1Userdata = server1:info().userData

    -- no listening socket created because local port already in use
    server2Connected = server2:connected()
    server2Userdata = server2:info().userData

    -- port should not change because already connected
    client:connect("localhost", port + 1)
    hs.timer.doAfter(0.2, function() clientConnectedPort = client:info().connectedPort end)
  end)

  server3 = hs.socket.server(sockfile)
  server4 = hs.socket.server(sockfile)
  clientUnix = hs.socket.new():connect(sockfile, function()
    server3Connected = server3:connected()
    server3Userdata = server3:info().userData

    -- no listening socket created because sockfile already bound for listening
    server4Connected = server4:connected()
    server4Userdata = server4:info().userData

    -- connected sockfile not change because already connected
    clientUnix:connect(sockfile.."2")
    hs.timer.doAfter(0.2, function() clientSockfile = clientUnix:info().unixSocketPath end)
  end)

  return success()
end

-- client and server userdata strings
function testTcpUserdataStringsValues()
  local serverHostPort = serverLocalHost..":"..serverLocalPort
  local clientHostPort = clientConnectedHost..":"..clientConnectedPort

  local serverUserdataHostPort = hs.fnutils.split(serverUserdataString, " ")[2]
  local clientUserdataHostPort = hs.fnutils.split(clientUserdataString, " ")[2]

  if (serverHostPort == serverUserdataHostPort and clientHostPort == clientUserdataHostPort) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpUserdataStrings()
  server = hs.socket.server(port)
  client = hs.socket.new():connect("localhost", port, function()
    serverUserdataString = tostring(server)
    serverLocalHost = server:info().localHost
    serverLocalPort = server:info().localPort

    clientUserdataString = tostring(client)
    clientConnectedHost = client:info().connectedHost
    clientConnectedPort = client:info().connectedPort
  end)

  return success()
end

-- reading and writing data
function testTcpClientServerReadWriteDelimiterValues()
  if (type(serverReadData) == "string" and serverReadData == "Hi from client\n" and
      type(clientReadData) == "string" and clientReadData == "Hello from server\n") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpClientServerReadWriteDelimiter()
  server = hs.socket.server(port, print)
  client = hs.socket.new(print):connect("localhost", port, function()
    -- clear and set new callbacks
    local function serverCallback(data) serverReadData = data end
    local function clientCallback(data) clientReadData = data end
    server:setCallback(nil)
    client:setCallback(nil)
    server:setCallback(serverCallback)
    client:setCallback(clientCallback)

    client:write("Hi from client\n", function()
      assertIsUserdataOfType("hs.socket", server:read("\n"))
      server:write("Hello from server\n", function()
        assertIsUserdataOfType("hs.socket", client:read("\n"))
      end)
    end)
  end)

  return success()
end

function testTcpClientServerReadWriteBytesValues()
  if (type(serverReadData) == "string" and serverReadData == "Hi fr" and
      type(clientReadData) == "string" and clientReadData == "Hello") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpClientServerReadWriteBytes()
  local function serverCallback(data) serverReadData = data end
  local function clientCallback(data) clientReadData = data end

  server = hs.socket.server(port, serverCallback)
  client = hs.socket.new(clientCallback):connect("localhost", port, function()
    local tag = 10
    client:write("Hi from client\n", tag, function(writeTag)
      assertIsEqual(tag, writeTag)
      server:read(5)
      server:write("Hello from server\n", function(writeTag)
        assertIsEqual(-1, writeTag)
        client:read(5)
      end)
    end)
  end)

  return success()
end

function testTcpUnixClientServerReadWriteBytesValues()
  print(serverReadData)
  print(clientReadData)
  if (type(serverReadData) == "string" and serverReadData == "Hi fr" and
      type(clientReadData) == "string" and clientReadData == "Hello") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpUnixClientServerReadWriteBytes()
  local function serverCallback(data) serverReadData = data end
  local function clientCallback(data) clientReadData = data end

  server = hs.socket.server(sockfile, serverCallback)
  client = hs.socket.new(clientCallback):connect(sockfile, function()
    local tag = 10
    client:write("Hi from client\n", tag, function(writeTag)
      assertIsEqual(tag, writeTag)
      server:read(5)
      server:write("Hello from server\n", function(writeTag)
        assertIsEqual(-1, writeTag)
        client:read(5)
      end)
    end)
  end)

  return success()
end

-- tagging
function testTcpTaggingValues()
  if (type(readData) == "string" and readData:sub(1,6) == "<HTML>" and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpTagging()
  local TAG_HTTP_HEADER = 1
  local TAG_HTTP_CONTENT = 2

  local function httpCallback(data, tag)
    if tag == TAG_HTTP_HEADER then
      local _, _, contentLength = data:find("\r\nContent%-Length: (%d+)\r\n");
      client:read(tonumber(contentLength), TAG_HTTP_CONTENT)
    elseif tag == TAG_HTTP_CONTENT then
      readData = data
    end
  end

  client = hs.socket.new(httpCallback):connect("google.com", 80, function()
    client:write("GET /index.html HTTP/1.0\r\nHost: google.com\r\n\r\n")
    client:read("\r\n\r\n", TAG_HTTP_HEADER)
    hs.timer.doAfter(2, function() clientConnected = client:connected() end)
  end)

  return success()
end

-- timeout
function testTcpClientServerTimeoutValues()
  if (type(clientConnected) == "boolean" and clientConnected == true and
      type(clientConnectedAfterTimeout) == "boolean" and clientConnectedAfterTimeout == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpClientServerTimeout()
  local server = hs.socket.server(port, print)
  client = hs.socket.new(print):connect("localhost", port, function()
    clientConnected = client:connected()
    client:setTimeout(1)
    client:read("\n") -- waiting for server to send data ending in '\n' which will time out
    hs.timer.doAfter(2, function() clientConnectedAfterTimeout = client:connected() end)
  end)

  return success()
end

-- TLS
function testTcpTlsValues()
  if (type(readData) == "string" and readData:sub(1,15) == "HTTP/1.1 200 OK" and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpTls()
  client = hs.socket.new(callback):connect("github.com", 443, function()
    client:startTLS()
    client:write("HEAD / HTTP/1.0\r\nHost: github.com\r\nConnection: Close\r\n\r\n");
    client:read("\r\n\r\n");
    hs.timer.doAfter(2, function() clientConnected = client:connected() end)
  end)

  return success()
end

-- make sure github disconnects us if operations attempted on unsecured socket
function testTcpTlsRequiredByServerValues()
  if (type(readData) == "nil" and readData == nil and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpTlsRequiredByServer()
  client = hs.socket.new(callback):connect("github.com", 443, function()
    client:write("HEAD / HTTP/1.0\r\nHost: github.com\r\nConnection: Close\r\n\r\n");
    client:read("\r\n\r\n");
    hs.timer.doAfter(2, function() clientConnected = client:connected() end)
  end)

  return success()
end

-- verify peer name
function testTcpTlsVerifyPeerValues()
  if (type(readData) == "string" and readData:sub(1,15) == "HTTP/1.1 200 OK") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpTlsVerifyPeer()
  client = hs.socket.new(callback):connect("github.com", 443, function()
    client:startTLS("github.com")
    client:write("HEAD / HTTP/1.0\r\nHost: github.com\r\nConnection: Close\r\n\r\n");
    client:read("\r\n\r\n");
  end)

  return success()
end

-- make sure TLS handshake fails on bad peer
function testTcpTlsVerifyBadPeerFailsValues()
  if (type(readData) == "nil" and readData == nil and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpTlsVerifyBadPeerFails()
  client = hs.socket.new(callback):connect("github.com", 443, function()
    client:startTLS("bitbucket.org")
    client:write("HEAD / HTTP/1.0\r\nHost: github.com\r\nConnection: Close\r\n\r\n");
    client:read("\r\n\r\n");
    hs.timer.doAfter(2, function() clientConnected = client:connected() end)
  end)

  return success()
end

-- no verification should work fine
function testTcpTlsNoVerifyValues()
  if (type(readData) == "string" and readData:sub(1,15) == "HTTP/1.1 200 OK" and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpTlsNoVerify()
  client = hs.socket.new(callback):connect("github.com", 443, function()
    client:startTLS(false)
    client:write("HEAD / HTTP/1.0\r\nHost: github.com\r\nConnection: Close\r\n\r\n");
    client:read("\r\n\r\n");
    hs.timer.doAfter(2, function() clientConnected = client:connected() end)
  end)

  return success()
end

-- no callback should fail on read attempt
function testTcpNoCallbackReadValues()
  if (type(result) == "nil" and result == nil) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTcpNoCallbackRead()
  local server = hs.socket.server(port)
  client = hs.socket.new():connect("localhost", port, function()
      result = client:read(1)
    end)

  return success()
end

-- address parsing
function testTcpParseAddress()
  -- sockaddr structure:
  --  1 byte   size
  --  1 byte   family
  --  2 bytes  port
  -- IPv4
  --  4 bytes  IPv4 address
  --  8 bytes  zeros    - (total 16 bytes)
  -- IPv6
  --  4 bytes  flowinfo
  --  16 bytes IPv6 address
  --  4 bytes  scope ID - (total 28 bytes)

  -- ipv4.google.com
  host_IPv4 = "216.58.218.110"
  port_IPv4 = 80
  AF_IPv4 = 2 -- AF_INET
  --                       IPv4   80 216.58.218.110
  addr_IPv4 = string.char(16,02,0,80,216,58,218,110,0,0,0,0,0,0,0,0)

  -- ipv6.google.com
  host_IPv6 = "2607:f8b0:4000:800::200e"
  port_IPv6 = 80
  AF_IPv6 = 30 -- AF_INET6
  --                       IPv6   80           26   07 : f8   b0 : 40   00 : 08   00 :                             : 20   0e
  addr_IPv6 = string.char(28,30,0,80,0,0,0,0,0x26,0x07,0xf8,0xb0,0x40,0x00,0x08,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x20,0x0e,0,0,0,0)


  local addr4 = hs.socket.parseAddress(addr_IPv4)
  local addr6 = hs.socket.parseAddress(addr_IPv6)

  assertIsEqual(host_IPv4, addr4.host)
  assertIsEqual(port_IPv4, addr4.port)
  assertIsEqual(AF_IPv4, addr4.addressFamily)

  assertIsEqual(host_IPv6, addr6.host)
  assertIsEqual(port_IPv6, addr6.port)
  assertIsEqual(AF_IPv6, addr6.addressFamily)

  return success()
end

function testTcpParseBadAddress()
  assertIsNil(hs.socket.parseAddress("nonsense"))

  return success()
end
