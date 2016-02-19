-- hs.socket tests

-- globals for async tests
port = 9001

serverLocalHost = nil
clientConnectedHost = nil

serverConnected = nil
serverConnections = nil
clientConnected = nil
clientConnections = nil

serverUserdata = nil
server2Connected = nil
server2Userdata = nil

clientConnectedAfterTimeout = nil

serverConnectedAfterDisconnect = nil
serverConnectionsAfterDisconnect = nil
clientConnectedAfterDisconnect = nil
clientConnectionsAfterDisconnect = nil

serverLocalPort = nil
clientConnectedPort = nil
serverDisconnectedPort = nil
clientDisconnectedPort = nil

server2LocalPort = nil
client2ConnectedPort = nil
server2DisconnectedPort = nil
client2DisconnectedPort = nil

serverUserdataString = nil
clientUserdataString = nil

serverReadData = nil
clientReadData = nil

globalClient = nil

readData = nil
readTag = nil

callback = function(data, tag)
  readData = data
  readTag = tag
end

-- constructors
function testDefaultSocketCreation()
  assertIsUserdataOfType("hs.socket", hs.socket.new("localhost", port))
  return success()
end

function testDefaultSocketCreationWithCallback()
  assertIsUserdataOfType("hs.socket", hs.socket.new("localhost", port, function(data) print(data) end))
  return success()
end

function testListenerSocketCreation()
  assertIsUserdataOfType("hs.socket", hs.socket.server(port))
  return success()
end

function testListenerSocketCreationWithCallback()
  assertIsUserdataOfType("hs.socket", hs.socket.server(port, function(data) print(data) end))
  return success()
end

-- listener socket
function testListenerSocketAttributes()
  local server = hs.socket.server(port, function(data) print(data) end)

  local info = server:info()

  assertIsEqual(port, info.localPort)
  assertIsEqual("0.0.0.0", info.localHost)
  assertIsEqual(0, info.connectedPort)
  assertIsEqual("", info.connectedHost)
  assertFalse(info.isConnected)  
  return success()
end

-- reusing client and server sockets
function testDisconnectAndReuseValues()
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

function testDisconnectAndReuse()
  local server = hs.socket.server(port)
  local client = hs.socket.new("localhost", port)

  hs.timer.doAfter(0.1, function()
    serverLocalPort = server:info().localPort
    clientConnectedPort = client:info().connectedPort

    server:disconnect()

    hs.timer.doAfter(0.1, function()
      serverDisconnectedPort = server:info().localPort
      clientDisconnectedPort = client:info().connectedPort

      -- switch roles
      client:listen(port)
      server:connect("localhost", port)

      hs.timer.doAfter(0.1, function()
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
function testConnectedValues()
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

function testConnected()
  local server = hs.socket.server(port)
  local client = hs.socket.new("localhost", port)
  local client2 = hs.socket.new("localhost", port)
  local client3 = hs.socket.new("localhost", port)

  hs.timer.doAfter(0.1, function()
    serverConnected = server:connected()
    serverConnections = server:connections()
    clientConnected = client:connected()
    clientConnections = client:connections()

    server:disconnect()

    hs.timer.doAfter(0.1, function()
      serverConnectedAfterDisconnect = server:connected()
      serverConnectionsAfterDisconnect = server:connections()
      clientConnectedAfterDisconnect = client:connected()
      clientConnectionsAfterDisconnect = client:connections()
    end)
  end)

  return success()
end

-- test failure to connect already connected sockets
function testAlreadyConnectedValues()
  if (type(serverConnected) == "boolean" and serverConnected == true and
      type(serverUserdata) == "string" and serverUserdata == "SERVER" and
      type(server2Connected) == "boolean" and server2Connected == false and
      type(server2Userdata) == "string" and server2Userdata == "" and
      type(clientConnectedPort) == "number" and clientConnectedPort == port) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testAlreadyConnected()
  local server = hs.socket.server(port)
  local server2 = hs.socket.server(port)
  local client = hs.socket.new("localhost", port)

  hs.timer.doAfter(0.1, function()
    serverConnected = server:connected()
    serverUserdata = server:info().userData

    -- no listening socket created because local port already in use
    server2Connected = server2:connected()
    server2Userdata = server2:info().userData

    -- port should not change because already connected
    client:connect("localhost", port + 1)

    hs.timer.doAfter(0.1, function()
      clientConnectedPort = client:info().connectedPort
    end)
  end)

  return success()
end

-- client and server userdata strings
function testUserdataStringValues()
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

function testUserdataStrings()
  local server = hs.socket.server(port)
  local client = hs.socket.new("localhost", port)

  hs.timer.doAfter(0.1, function()
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
function testClientServerReadWriteDelimiterValues()
  if (type(serverReadData) == "string" and serverReadData == "Hi from client\n" and
      type(clientReadData) == "string" and clientReadData == "Hello from server\n") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testClientServerReadWriteDelimiter()
  local server = hs.socket.server(port, function(data) print(data) end)
  local client = hs.socket.new("localhost", port, function(data) print(data) end)

  -- clear default print callbacks
  server:setCallback(nil)
  client:setCallback(nil)

  -- set new callbacks
  local function serverCallback(data)
    serverReadData = data
  end

  local function clientCallback(data)
    clientReadData = data
  end

  server:setCallback(serverCallback)
  client:setCallback(clientCallback)

  -- send data
  client:write("Hi from client\n")

  hs.timer.doAfter(.1, function()
    assertIsUserdataOfType("hs.socket", server:read("\n"))
    server:write("Hello from server\n")

    hs.timer.doAfter(.1, function()
      assertIsUserdataOfType("hs.socket", client:read("\n"))
    end)
  end)

  return success()
end

function testClientServerReadWriteBytesValues()
  if (type(serverReadData) == "string" and serverReadData == "Hi fr" and
      type(clientReadData) == "string" and clientReadData == "Hello") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testClientServerReadWriteBytes()
  local server = hs.socket.server(port, function(data) print(data) end)
  local client = hs.socket.new("localhost", port, function(data) print(data) end)

  -- clear default print callbacks
  server:setCallback(nil)
  client:setCallback(nil)

  -- set new callbacks
  local function serverCallback(data)
    serverReadData = data
  end

  local function clientCallback(data)
    clientReadData = data
  end

  server:setCallback(serverCallback)
  client:setCallback(clientCallback)

  -- send data
  client:write("Hi from client\n")

  hs.timer.doAfter(.1, function()
    assertIsUserdataOfType("hs.socket", server:read(5))
    server:write("Hello from server\n")

    hs.timer.doAfter(.1, function()
      assertIsUserdataOfType("hs.socket", client:read(5))
    end)
  end)

  return success()
end

-- tagging
function testTaggingValues()
  if (type(readData) == "string" and readData:sub(1,6) == "<HTML>" and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTagging()
  local TAG_HTTP_HEADER = 1
  local TAG_HTTP_CONTENT = 2

  local function httpCallback(data, tag)
    if tag == TAG_HTTP_HEADER then
      local _, _, contentLength = data:find("\r\nContent%-Length: (%d+)\r\n");
      globalClient:read(tonumber(contentLength), TAG_HTTP_CONTENT)
    elseif tag == TAG_HTTP_CONTENT then
      readData = data
    end
  end

  globalClient = hs.socket.new("google.com", 80, httpCallback)
  globalClient:write("GET /index.html HTTP/1.0\r\nHost: google.com\r\n\r\n")
  globalClient:read("\r\n\r\n", TAG_HTTP_HEADER)

  hs.timer.doAfter(2, function()
    clientConnected = globalClient:connected()
  end)

  return success()
end

-- timeout
function testClientServerTimeoutValues()
  if (type(clientConnected) == "boolean" and clientConnected == true and
      type(clientConnectedAfterTimeout) == "boolean" and clientConnectedAfterTimeout == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testClientServerTimeout()
  local server = hs.socket.server(port, function(data) print(data) end)
  local client = hs.socket.new("localhost", port, function(data) print(data) end)

  client:setTimeout(1)
  -- waiting for server to send data ending in '\n'
  client:read("\n")

  hs.timer.doAfter(.1, function()
    clientConnected = client:connected()
    hs.timer.doAfter(2, function()
      clientConnectedAfterTimeout = client:connected()
    end)
  end)

  return success()
end

-- TLS
function testTLSValues()
  if (type(readData) == "string" and readData:sub(1,15) == "HTTP/1.1 200 OK" and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTLS()
  local client = hs.socket.new("github.com", 443, callback)

  client:startTLS()
  client:write("HEAD / HTTP/1.0\r\nHost: github.com\r\nConnection: Close\r\n\r\n");
  client:read("\r\n\r\n");

  hs.timer.doAfter(2, function()
    clientConnected = client:connected()
  end)

  return success()
end

-- make sure github disconnects us if operations attempted on unsecured socket
function testNoTLSWhenRequiredByServerValues()
  if (type(readData) == "nil" and readData == nil and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testNoTLSWhenRequiredByServer()
  local client = hs.socket.new("github.com", 443, callback)

  client:write("HEAD / HTTP/1.0\r\nHost: github.com\r\nConnection: Close\r\n\r\n");
  client:read("\r\n\r\n");

  hs.timer.doAfter(2, function()
    clientConnected = client:connected()
  end)

  return success()
end

-- verify peer name
function testTLSVerifyPeerValues()
  if (type(readData) == "string" and readData:sub(1,15) == "HTTP/1.1 200 OK" and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTLSVerifyPeer()
  local client = hs.socket.new("github.com", 443, callback)

  client:startTLS(true, "github.com")
  client:write("HEAD / HTTP/1.0\r\nHost: github.com\r\nConnection: Close\r\n\r\n");
  client:read("\r\n\r\n");

  hs.timer.doAfter(2, function()
    clientConnected = client:connected()
  end)

  return success()
end

-- make sure TLS handshake fails on bad peer
function testTLSVerifyBadPeerFailsValues()
  if (type(readData) == "nil" and readData == nil and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTLSVerifyBadPeerFails()
  local client = hs.socket.new("github.com", 443, callback)

  client:startTLS(true, "bitbucket.org")
  client:write("HEAD / HTTP/1.0\r\nHost: github.com\r\nConnection: Close\r\n\r\n");
  client:read("\r\n\r\n");

  hs.timer.doAfter(2, function()
    clientConnected = client:connected()
  end)

  return success()
end

-- no verification should work fine
function testTLSNoVerifyValues()
  if (type(readData) == "string" and readData:sub(1,15) == "HTTP/1.1 200 OK" and
      type(clientConnected) == "boolean" and clientConnected == false) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testTLSNoVerify()
  local client = hs.socket.new("github.com", 443, callback)

  client:startTLS(false)
  client:write("HEAD / HTTP/1.0\r\nHost: github.com\r\nConnection: Close\r\n\r\n");
  client:read("\r\n\r\n");

  hs.timer.doAfter(2, function()
    clientConnected = client:connected()
  end)

  return success()
end

-- no callback should fail on read attempt
function testNoCallbackRead()
  local server = hs.socket.server(port)
  local client = hs.socket.new("localhost", port)

  local result = client:read(5)
  assertIsNil(result)

  return success()
end

-- address parsing
function testParseAddress()
  -- sockaddr structure:
  --  1 byte   size
  --  1 byte   family
  --  2 bytes  port
  -- ipv4
  --  4 bytes  ipv4 address
  --  8 bytes  zeros    - (total 16 bytes)
  -- ipv6
  --  4 bytes  flowinfo
  --  16 bytes ipv6 address
  --  4 bytes  scope ID - (total 28 bytes)

  -- ipv4.google.com
  host_IPv4 = "216.58.218.110"
  port_IPv4 = 80
  AF_IPv4 = 2 -- AF_INET
  --                       ipv4   80 216.58.218.110
  addr_IPv4 = string.char(16,02,0,80,216,58,218,110,0,0,0,0,0,0,0,0)

  -- ipv6.google.com
  host_IPv6 = "2607:f8b0:4000:800::200e"
  port_IPv6 = 80
  AF_IPv6 = 30 -- AF_INET6
  --                       ipv6   80                       26   07 : f8   b0 : 40   00 : 08   00 :                             : 20   0e
  addr_IPv6 = string.char(28,30,0,80,0x00,0x00,0x00,0x00,0x26,0x07,0xf8,0xb0,0x40,0x00,0x08,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x20,0x0e,0x00,0x00,0x00,0x00)


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
