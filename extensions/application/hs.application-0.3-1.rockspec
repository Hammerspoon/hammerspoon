package = "hs.application"
version = "0.3-1"
local url = "github.com/hammerspoon/hammerspoon"
local desc = "Hammerspoon module to inspect and manipulate running applications and their windows."
source = {url = "git://" .. url}
description = {
  summary = desc,
  detailed = desc,
  homepage = "https://" .. url,
  license = "MIT",
}
supported_platforms = {"macosx"}
dependencies = {
  "lua >= 5.2",
  "hs.fnutils",
  "hs.geometry",
  "hs.screen",
}
build = {
  type = "builtin",
  modules = {
    ["hs.application"] = "application.lua",
    ["hs.application.internal"] = "application.m",
    ["hs.window"] = "window.lua",
    ["hs.window.internal"] = "window.m",
  },
}
