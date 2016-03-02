function testUdpSocketCreation()
  assertIsUserdataOfType("hs.socket.udp", hs.socket.udp.new())
  return success()
end
