package = "mjolnir.application"
version = "0.3-1"
local url = "github.com/mjolnir-io/mjolnir-modules"
local desc = "Mjolnir module to inspect and manipulate running applications and their windows."
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
  "mjolnir.fnutils",
  "mjolnir.geometry",
  "mjolnir.screen",
}
build = {
  type = "builtin",
  modules = {
    ["mjolnir.application"] = "application.lua",
    ["mjolnir.application.internal"] = "application.m",
    ["mjolnir.window"] = "window.lua",
    ["mjolnir.window.internal"] = "window.m",
  },
}
