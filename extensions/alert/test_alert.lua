function testAlert()
  hs.alert.show("Test alert 1")
  hs.alert("Test alert 2", 20)

  return success()
end

function testCloseAll()
  hs.alert.closeAll()

  return success()
end
