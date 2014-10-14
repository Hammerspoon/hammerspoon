package = "hs.screen"
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
  "hs.fnutils",
  "hs.geometry",
}
build = {
  type = "builtin",
  modules = {
    ["hs.screen"] = "screen.lua",
    ["hs.screen.internal"] = "screen.m",
  },
}
