function testLoadWithoutDockProcess()
  local application = require("hs.application")
  local applicationsForBundleID = application.applicationsForBundleID
  local loaded = package.loaded["hs.spaces"]

  application.applicationsForBundleID = function() return {} end
  package.loaded["hs.spaces"] = nil
  local ok, result = pcall(require, "hs.spaces")
  application.applicationsForBundleID = applicationsForBundleID
  package.loaded["hs.spaces"] = loaded

  if not ok then failure(tostring(result)) end
  assertIsTable(result)

  return success()
end
