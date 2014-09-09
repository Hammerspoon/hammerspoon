package = "mjolnir.screen"
version = "0.2-1"
local url = "github.com/mjolnir-io/mjolnir-modules"
local desc = "Mjolnir module to inspect and manipulate screens (i.e. monitors)."
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
}
build = {
  type = "builtin",
  modules = {
    ["mjolnir.screen"] = "screen.lua",
    ["mjolnir.screen.internal"] = "screen.m",
  },
}
