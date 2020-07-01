hs.socket = require("hs.socket")
hs.timer = require("hs.timer")
hs.fnutils = require("hs.fnutils")

-- globals for async UDP tests
port = 9001

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

function testUdpConnect()
  local server = hs.socket.udp.server(port)
  local client1 = hs.socket.udp.new():connect("localhost", port)
  local client2 = hs.socket.udp.new():connect("localhost", 0)

  local client1Info = client1:info()
  local client2Info = client2:info()
  assertTrue(client1Info.isConnected)
  assertFalse(client2Info.isConnected)

  return success()
end

function testUdpNoCallbacks()
  assertIsNil(hs.socket.udp.new():receive())
  assertIsNil(hs.socket.udp.new():receiveOne())

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
  if (type(server1Closed) == "boolean" and server1Closed == false and
      type(server1Userdata) == "string" and server1Userdata == "SERVER" and
      type(server2Closed) == "boolean" and server2Closed == true and
      type(server2Userdata) == "string" and server2Userdata == "" and
      type(clientConnectedPort) == "number" and clientConnectedPort == port) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpAlreadyConnected()
  server1 = hs.socket.udp.server(port)
  server2 = hs.socket.udp.server(port)
  client = hs.socket.udp.new():connect("localhost", port, function()
    server1Closed = server1:closed()
    server1Userdata = server1:info().userData

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

-- reading and writing data
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
  client = hs.socket.udp.new(print):connect("localhost", port, function()
    -- clear and set new callbacks
    local function serverCallback(data) serverReadData = data end
    local function clientCallback(data) clientReadData = data end
    server:setCallback(nil)
    client:setCallback(nil)
    server:setCallback(serverCallback)
    client:setCallback(clientCallback)

    server:receiveOne()
    client:receiveOne()

    client:write("Hi from client\n", 10, function(writeTag)
      assertIsEqual(10, writeTag)
      server:write("Hello from server\n", "localhost", client:info().localPort, function(writeTag)
        assertIsEqual(-1, writeTag)
        client:write("Hi again from client\n", function(writeTag)
          server:write("Hello again from server\n", "localhost", client:info().localPort)
        end)
      end)
    end)
  end)

  return success()
end

function testUdpClientServerReceiveManyValues()
  if (type(clientConnected) == "boolean" and clientConnected == true and
      type(serverReadData) == "string" and serverReadData == "Hi from client\nHi again from client\n" and
      type(clientReadData) == "string" and clientReadData == "Hello from server\nHello again from server\n") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpClientServerReceiveMany()
  local function serverCallback(data) serverReadData = serverReadData..data end
  local function clientCallback(data) clientReadData = clientReadData..data end
  serverReadData, clientReadData = "", ""
  server = hs.socket.udp.new():listen(port)
  client = hs.socket.udp.new():connect("localhost", port, function()
    server:receive(serverCallback)
    client:receive(clientCallback)
    clientConnected = client:connected()

    client:write("Hi from client\n", 10, function(writeTag)
      client:pause()
      assertIsEqual(10, writeTag)
      server:write("Hello from server\n", "localhost", client:info().localPort, 20, function(writeTag)
        assertIsEqual(20, writeTag)
        client:write("Hi again from client\n", function(writeTag)
          client:receive()
          server:write("Hello again from server\n", "localhost", client:info().localPort)
        end)
      end)
    end)
  end)

  return success()
end

function testUdpBroadcastValues()
  if (type(serverReadData) == "string" and serverReadData == "Hi from client\n" and
      type(clientReadData) == "string" and clientReadData == "Hello from server\n") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpBroadcast()
  local function serverCallback(data) serverReadData = data end
  local function clientCallback(data) clientReadData = data end
  server = hs.socket.udp.server(port, serverCallback):receive()
  client = hs.socket.udp.new(clientCallback)
  client:broadcast():send("Hi from client\n", "255.255.255.255", port, function()
    client:receive()
    server:write("Hello from server\n", "localhost", client:info().localPort)
  end)

  return success()
end

function testUdpReusePortValues()
  if (type(server1ReadData) == "string" and server1ReadData == "server1:Hello\n" and
      type(server2ReadData) == "string" and server2ReadData == "server2:Hello\n") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpReusePort()
  local function server1Callback(data) server1ReadData = "server1:"..data end
  local function server2Callback(data) server2ReadData = "server2:"..data end
  server1 = hs.socket.udp.new():reusePort():listen(port):receiveOne(server1Callback)
  server2 = hs.socket.udp.new():reusePort():listen(port):receiveOne(server2Callback)
  client = hs.socket.udp.new():broadcast()
  client:send("Hello\n", "255.255.255.255", port, function() client:broadcast(false) end)

  return success()
end

-- ip versions
function testUdpEnabledIpVersionValues()
  if (type(server1ReadData) == "string" and server1ReadData == "server1:Hello\n" and
      type(server2ReadData) == "string" and server2ReadData == "server2:Hello\n" and
      type(server1AddressFamily) == "number" and server1AddressFamily == 30 and
      type(server2AddressFamily) == "number" and server2AddressFamily == 2) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpEnabledIpVersion()
  local function server1Callback(data, addr)
    server1ReadData = "server1:"..data
    server1AddressFamily = hs.socket.udp.parseAddress(addr).addressFamily
  end
  local function server2Callback(data, addr)
    server2ReadData = "server2:"..data
    server2AddressFamily = hs.socket.udp.parseAddress(addr).addressFamily
  end
  server1 = hs.socket.udp.new(server1Callback):enableIPv(4, false):reusePort():listen(port):receiveOne()
  server2 = hs.socket.udp.new(server2Callback):enableIPv(6, false):reusePort():listen(port):receiveOne()
  client = hs.socket.udp.new():setTimeout(1)
  client:preferIPv(4):broadcast():send("Hello\n", "255.255.255.255", port)
  assertIsNil(client:enableIPv(0))

  return success()
end

function testUdpPreferredIpVersionValues()
  if (type(client1SentData) == "string" and client1SentData == "Client1\n" and
      type(client1AddressFamily) == "number" and client1AddressFamily == 2 and
      type(client2SentData) == "string" and client2SentData == "Client2\n" and
      type(client2AddressFamily) == "number" and client2AddressFamily == 30) then
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpPreferredIpVersion()
  local function serverCallback(data, addr)
    if data:match("Client1") then
      client1SentData = data
      client1AddressFamily = hs.socket.udp.parseAddress(addr).addressFamily
    elseif data:match("Client2") then
      client2SentData = data
      client2AddressFamily = hs.socket.udp.parseAddress(addr).addressFamily
    end
  end
  server = hs.socket.udp.server(port, serverCallback):preferIPv(4):preferIPv(6):preferIPv():receive()
  hs.socket.udp.new():preferIPv(4):broadcast():send("Client1\n", "localhost", port)
  hs.socket.udp.new():preferIPv(6):broadcast():send("Client2\n", "localhost", port)

  return success()
end

function testUdpBufferSizeValues()
  if (type(server1ReadData) == "nil" and server1ReadData == nil and
      type(server2ReadData) == "string" and server2ReadData == "0123" and
      type(server3ReadData) == "string" and server3ReadData == "01234567" and
      type(server4ReadData) == "string" and server4ReadData == "0123456789abcdef") then
    return success()
  else
    return "Waiting for success..."
  end
end

function testUdpBufferSize()
  local function server1Callback(data) server1ReadData = data end
  local function server2Callback(data) server2ReadData = data end
  local function server3Callback(data) server3ReadData = data end
  local function server4Callback(data) server4ReadData = data end
  server1 = hs.socket.udp.new():reusePort():listen(port):setBufferSize(0):receiveOne(server1Callback)
  server2 = hs.socket.udp.new():reusePort():listen(port):setBufferSize(4):receiveOne(server2Callback)
  server3 = hs.socket.udp.new():reusePort():listen(port):setBufferSize(8):receiveOne(server3Callback)
  server4 = hs.socket.udp.new():reusePort():listen(port):receiveOne(server4Callback)
  client = hs.socket.udp.new():broadcast()
  client:send("0123456789abcdef", "255.255.255.255", port, function() client:broadcast(false) end)

  local info = client:info()
  assertIsEqual(65535, info.maxReceiveIPv4BufferSize)
  assertIsEqual(65535, info.maxReceiveIPv6BufferSize)

  info = client:setBufferSize(4294967296):info()
  assertIsEqual(65535, info.maxReceiveIPv4BufferSize)
  assertIsEqual(4294967295, info.maxReceiveIPv6BufferSize)

  info = client:setBufferSize(1000, 4):setBufferSize(2000, 6):info()
  assertIsEqual(1000, info.maxReceiveIPv4BufferSize)
  assertIsEqual(2000, info.maxReceiveIPv6BufferSize)

  info = client:setBufferSize(-1):info()
  assertIsEqual(65535, info.maxReceiveIPv4BufferSize)
  assertIsEqual(4294967295, info.maxReceiveIPv6BufferSize)

  return success()
end
