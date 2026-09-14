hs.spotify = require("hs.spotify")

function testIsRunningIgnoresWindowTitles()
  if #hs.application.applicationsForBundleID("com.spotify.client") > 0 then
    return success()
  end

  local wv = hs.webview.new({x=100, y=100, w=300, h=200}):windowStyle({"titled"}):windowTitle("Spotify test"):show()
  local found = hs.application.get("Spotify")
  local running = hs.spotify.isRunning()
  wv:delete()

  assertIsNotNil(found)
  assertIsEqual(false, running)

  return success()
end
