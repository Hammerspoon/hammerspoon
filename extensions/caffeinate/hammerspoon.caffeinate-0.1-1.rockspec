-- `package` is the require-path.
--
--    Note: this must match the filename also.
package = "hs.caffeinate"

-- `version` has two parts, your module's version (0.1) and the
--    rockspec's version (1) in case you change metadata without
--    changing the module's source code.
--
--    Note: the version must match the version in the filename.
version = "0.1-1"

-- General metadata:

local url = "github.com/hammerspoon/hammerspoon"
local desc = "Hammerspoon module to prevent display/system sleep"

source = {url = "git://" .. url}
description = {
  summary = desc,
  detailed = desc,
  homepage = "https://" .. url,
  license = "MIT",
}

-- Dependencies:

supported_platforms = {"macosx"}
dependencies = {
  "lua >= 5.2",
}

-- Build rules:

build = {
  type = "builtin",
  modules = {
    -- This is the top-level module:
    ["hs.caffeinate"] = "caffeinate.lua",

    -- If you have an internal C or Objective-C submodule, include it here:
    ["hs.caffeinate.internal"] = "caffeinate.m",
  },
}
