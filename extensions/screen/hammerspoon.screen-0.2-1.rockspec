package = "hammerspoon.screen"
version = "0.2-1"
local url = "github.com/hammerspoon/hammerspoon"
local desc = "Hammerspoon module to inspect and manipulate screens (i.e. monitors)."
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
}
build = {
  type = "builtin",
  modules = {
    ["hammerspoon.screen"] = "screen.lua",
    ["hammerspoon.screen.internal"] = "screen.m",
  },
}
