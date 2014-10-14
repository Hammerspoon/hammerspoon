package = "hs.hotkey"
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
  "hs.keycodes",
}
build = {
  type = "builtin",
  modules = {
    ["hs.hotkey"] = "hotkey.lua",
    ["hs.hotkey.internal"] = "hotkey.m",
  },
}
