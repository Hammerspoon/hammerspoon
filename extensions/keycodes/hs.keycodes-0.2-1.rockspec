package = "hs.keycodes"
version = "0.2-1"
local url = "github.com/hammerspoon/hammerspoon"
local desc = "Hammerspoon module to convert between key-strings and key-codes."
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
}
build = {
  type = "builtin",
  modules = {
    ["hs.keycodes"] = "keycodes.lua",
    ["hs.keycodes.internal"] = "keycodes.m",
  },
}
