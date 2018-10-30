hs.alert = require("hs.alert")

function testAlert()
  hs.alert.show("Test alert 1")
  hs.alert("Test alert 2", 20)
  hs.alert.show("Test alert at top edge", {atScreenEdge = 1})

  return success()
end

function testCloseAll()
  hs.alert.closeAll()

  return success()
end
