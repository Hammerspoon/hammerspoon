package = "hammerspoon.hotkey"
version = "0.3-1"
local url = "github.com/hammerspoon/hammerspoon"
local desc = "Hammerspoon module to create and manage global hotkeys."
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
  "hammerspoon.keycodes",
}
build = {
  type = "builtin",
  modules = {
    ["hammerspoon.hotkey"] = "hotkey.lua",
    ["hammerspoon.hotkey.internal"] = "hotkey.m",
  },
}
