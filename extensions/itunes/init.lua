--- === hs.itunes ===
---
--- Controls for iTunes music player

local itunes = {}

local alert = require "hs.alert"
local as = require "hs.applescript"

-- Internal function to pass a command to Applescript.
local function tell(cmd)
  local _cmd = 'tell application "iTunes" to ' .. cmd
  local _ok, result = as.applescript(_cmd)
  return result
end

--- hs.itunes.play() -> nil
--- Function
--- Toggles play/pause of current itunes track
function itunes.play()
  tell('playpause')
  alert.show(' ▶', 0.5)
end

--- hs.itunes.pause() -> nil
--- Function
--- Pauses of current itunes track
function itunes.pause()
  tell('pause')
  alert.show(' ◼', 0.5)
end

--- hs.itunes.next() -> nil
--- Function
--- Skips to the next itunes track
function itunes.next()
  tell('next track')
  alert.show(' ⇥', 0.5)
end

--- hs.itunes.previous() -> nil
--- Function
--- Skips to previous itunes track
function itunes.previous()
  tell('previous track')
  alert.show(' ⇤', 0.5)
end

--- hs.itunes.displayCurrentTrack() -> nil
--- Function
--- Displays information for current track
function itunes.displayCurrentTrack()
  artist = tell('artist of the current track as string')
  album  = tell('album of the current track as string')
  track  = tell('name of the current track as string')
  alert.show(track .."\n".. album .."\n".. artist, 1.75)
end

return itunes
