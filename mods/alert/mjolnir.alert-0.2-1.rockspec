package = "mjolnir.alert"
version = "0.2-1"
local url = "github.com/mjolnir-io/mjolnir-modules"
local desc = "Mjolnir module to show brief messages on-screen."
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
    ["mjolnir.alert"] = "alert.m",
  },
}
