-- hs.socket tests

-- globals for async tests
port = 9001

serverLocalHost = nil
clientConnectedHost = nil

serverConnected = nil
serverConnections = nil
clientConnected = nil
clientConnections = nil

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

-- no callback should fail on read attempt
function testNoCallbackRead()
  local server = hs.socket.server(port)
  local client = hs.socket.new("localhost", port)

  local result = client:read(5)
  assertIsNil(result)

  return success()
end

-- test failure to connect already connected sockets
function testAlreadyConnected()
  local server = hs.socket.server(port)
  local server2 = hs.socket.server(port)
  local server3 = hs.socket.server(port + 1)
  local client = hs.socket.new("localhost", port)

  -- no listening socket created because local port already in use
  assertFalse(server2:connected())
  assertIsEqual("", server2:info().socketType)

  -- port should not change because already connected
  client:connect("localhost", port + 1)
  assertIsEqual(port, client:info().connectedPort) 

  return success()
end
