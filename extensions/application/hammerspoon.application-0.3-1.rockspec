package = "hammerspoon.application"
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
  "hammerspoon.fnutils",
  "hammerspoon.geometry",
  "hammerspoon.screen",
}
build = {
  type = "builtin",
  modules = {
    ["hammerspoon.application"] = "application.lua",
    ["hammerspoon.application.internal"] = "application.m",
    ["hammerspoon.window"] = "window.lua",
    ["hammerspoon.window.internal"] = "window.m",
  },
}
