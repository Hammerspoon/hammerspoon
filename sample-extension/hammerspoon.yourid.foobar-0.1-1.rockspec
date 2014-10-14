-- `package` is the require-path.
--
--    Note: this must match the filename also.
package = "hs.yourid.foobar"

-- `version` has two parts, your module's version (0.1) and the
--    rockspec's version (1) in case you change metadata without
--    changing the module's source code.
--
--    Note: the version must match the version in the filename.
version = "0.1-1"

-- General metadata:

local url = "github.com/yourname/hs.yourid.foobar"
local desc = "Hammerspoon module to add and subtract numbers."

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
  -- You can add Hammerspoon core modules as dependencies,
  -- i.e. "hs.application", "hs.hotkey", whatever.
  --
  -- For example, if your module depends on `hs.fnutils`,
  -- uncomment the following line:
  --
  -- "hs.fnutils",
}

-- Build rules:

build = {
  type = "builtin",
  modules = {
    -- This is the top-level module:
    ["hs.yourid.foobar"] = "foobar.lua",

    -- If you have an internal C or Objective-C submodule, include it here:
    ["hs.yourid.foobar.internal"] = "foobar.m",

    -- Note: the key on the left side is the require-path; the value
    --       on the right is the filename relative to the current dir.
  },
}
