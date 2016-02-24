-- globals for async UDP tests
port = 9001

callback = function(data, address)
  readData = data
  readAddress = address
end

-- constructors
function testUdpSocketInstanceCreation()
  assertIsUserdataOfType("hs.socket.udp", hs.socket.udp.new())
  return success()
end

function testUdpSocketInstanceCreationWithCallback()
  assertIsUserdataOfType("hs.socket.udp", hs.socket.udp.new(print))
  return success()
end

function testUdpListenerSocketCreation()
  assertIsUserdataOfType("hs.socket.udp", hs.socket.udp.server(port))
  return success()
end

function testUdpListenerSocketCreationWithCallback()
  assertIsUserdataOfType("hs.socket.udp", hs.socket.udp.server(port, print))
  return success()
end

function testUdpListenerSocketAttributes()
  local server = hs.socket.udp.server(port, print)

  local info = server:info()

  assertIsEqual(port, info.localPort)
  assertIsEqual("0.0.0.0", info.localHost)
  assertIsEqual(0, info.connectedPort)
  assertIsEqual("", info.connectedHost)
  assertIsEqual("SERVER", info.userData)
  assertFalse(info.isConnected)
  return success()
end

-- reusing client and server sockets
function testUdpDisconnectAndReuseValues()
  if (type(serverLocalPort) == "number" and serverLocalPort == port and
      type(clientConnectedPort) == "number" and clientConnectedPort == port and
      type(serverDisconnectedPort) == "number" and serverDisconnectedPort == 0 and
      -- type(clientDisconnectedPort) == "number" and clientDisconnectedPort == 0 and -- issue in GCDAsyncUdpSocket not clearing cached connected info
      type(server2LocalPort) == "number" and server2LocalPort == port and
      type(client2ConnectedPort) == "number" and client2ConnectedPort == port and
      type(server2DisconnectedPort) == "number" and server2DisconnectedPort == 0) then
      -- type(client2DisconnectedPort) == "number" and client2DisconnectedPort == 0 -- issue in GCDAsyncUdpSocket not clearing cached connected info
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpDisconnectAndReuse()
  local server = hs.socket.udp.server(port)
  local client = hs.socket.udp.new():connect("localhost", port)

  hs.timer.doAfter(0.1, function()
    serverLocalPort = server:info().localPort
    clientConnectedPort = client:info().connectedPort

    server:close()
    client:close()

    hs.timer.doAfter(0.1, function()
      serverDisconnectedPort = server:info().localPort
      clientDisconnectedPort = client:info().connectedPort

      -- switch roles
      client:listen(port)
      server:connect("localhost", port)

      hs.timer.doAfter(0.1, function()
        server2LocalPort = client:info().localPort
        client2ConnectedPort = server:info().connectedPort

        client:close()
        server:close()

        hs.timer.doAfter(0.1, function()
          server2DisconnectedPort = client:info().localPort
          client2DisconnectedPort = server:info().connectedPort
        end)
      end)
    end)
  end)

  return success()
end

-- test failure to connect already connected sockets
function testUdpAlreadyConnectedValues()
  if (type(serverClosed) == "boolean" and serverClosed == false and
      type(serverUserdata) == "string" and serverUserdata == "SERVER" and
      type(server2Closed) == "boolean" and server2Closed == true and
      type(server2Userdata) == "string" and server2Userdata == "" and
      type(clientConnectedPort) == "number" and clientConnectedPort == port) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpAlreadyConnected()
  server = hs.socket.udp.server(port)
  server2 = hs.socket.udp.server(port)
  client = hs.socket.udp.new():connect("localhost", port, function()
    serverClosed = server:closed()
    serverUserdata = server:info().userData

    -- no listening socket created because local port already in use
    server2Closed = server2:closed()
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
function testUdpUserdataStringsValues()
  local unconnectedHostPort = unconnectedConnectedHost..":"..unconnectedConnectedPort
  local serverHostPort = serverLocalHost..":"..serverLocalPort
  local clientHostPort = clientConnectedHost..":"..clientConnectedPort

  local unconnectedUserdataHostPort = hs.fnutils.split(unconnectedUserdataString, " ")[2] 
  local serverUserdataHostPort = hs.fnutils.split(serverUserdataString, " ")[2] 
  local clientUserdataHostPort = hs.fnutils.split(clientUserdataString, " ")[2]

  if (unconnectedHostPort == unconnectedUserdataHostPort and 
    serverHostPort == serverUserdataHostPort and
    clientHostPort == clientUserdataHostPort) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpUserdataStrings()
  unconnected = hs.socket.udp.new()
  server = hs.socket.udp.server(port)
  client = hs.socket.udp.new():connect("localhost", port, function()
    unconnectedUserdataString = tostring(unconnected)
    unconnectedConnectedHost = "(null)"
    unconnectedConnectedPort = 0

    serverUserdataString = tostring(server)
    serverLocalHost = server:info().localHost
    serverLocalPort = server:info().localPort

    clientUserdataString = tostring(client)
    clientConnectedHost = client:info().connectedHost
    clientConnectedPort = client:info().connectedPort
  end)

  return success()
end

function testUdpClientServerReceiveOnceValues()
  if (type(serverReadData) == "string" and serverReadData == "Hi from client\n" and
      type(clientReadData) == "string" and clientReadData == "Hello from server\n") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpClientServerReceiveOnce()
  server = hs.socket.udp.server(port, print)
  client = hs.socket.udp.new(print):connect("localhost", port)

  -- set new callbacks
  local function serverCallback(data) serverReadData = data end
  local function clientCallback(data) clientReadData = data end

  server:setCallback(serverCallback)
  client:setCallback(clientCallback)

  server:receiveOne()
  client:receiveOne()

  -- send data
  local tag = 10
  client:write("Hi from client\n", tag, function(writeTag)
    assertIsEqual(tag, writeTag)
    server:write("Hello from server\n", "localhost", client:info().localPort, function(writeTag)
      assertIsEqual(-1, writeTag)
      client:write("Hi again from client\n", function(writeTag)
        server:write("Hello again from server\n", "localhost", client:info().localPort)
      end)
    end)
  end)

  return success()
end
