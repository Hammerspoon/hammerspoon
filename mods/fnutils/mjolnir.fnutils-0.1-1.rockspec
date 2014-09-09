package = "mjolnir.fnutils"
version = "0.1-1"
local url = "github.com/mjolnir-io/mjolnir-modules"
local desc = "Mjolnir module to help with functional programming."
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
    ["mjolnir.fnutils"] = "fnutils.lua",
  },
}
