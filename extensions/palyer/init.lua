--- === Music Player ===
---
--- Controls for Music player

--- Global Declaration ---

local player = {}

local alert = require "hs.alert"
local as = require "hs.applescript"
local app = require "hs.application"

-- Determine the main player
local function getPlayer()
  -- TODO:
end

-- Internal function to pass a command to Applescript.
local function tell(app, cmd)
  local _cmd = 'tell application ' .. app .. ' to ' .. cmd
  local ok, result = as.applescript(_cmd)
  if ok then
    return result
  else
    return nil
  end
end

-- Application state

--- hs.player.isRunning()
--- Function
--- Returns whether music player is currently running
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean value indicating whether the vox application is running
function player.isRunning()
  return app.get("VOX"):isRunning() ~= nil
end

return player
