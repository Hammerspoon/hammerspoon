--- === hs.spotify ===
--
-- Controls for spotify music player

local spotify = {}

local alert = require "hs.alert"
local as = require "hs.applescript"

-- Internal function to pass a command to Applescript.
local function tell(cmd)
  local _cmd = 'tell application "Spotify" to ' .. cmd
  local _ok, result = as.applescript(_cmd)
  return result
end

--- hs.spotify.play() -> nil
--- Function
--- Toggles play/pause of current spotify track
function spotify.play()
  tell('playpause')
  alert.show(' ▶', 0.5)
end

--- hs.spotify.pause() -> nil
--- Function
--- Pauses of current spotify track
function spotify.pause()
  tell('pause')
  alert.show(' ◼', 0.5)
end

--- hs.spotify.next() -> nil
--- Function
--- Skips to the next spotify track
function spotify.next()
  tell('next track')
  alert.show(' ⇥', 0.5)
end

--- hs.spotify.previous() -> nil
--- Function
--- Skips to previous spotify track
function spotify.previous()
  tell('previous track')
  alert.show(' ⇤', 0.5)
end

--- hs.spotify.displayCurrentTrack() -> nil
--- Function
--- Displays information for current track
function spotify.displayCurrentTrack()
  artist = tell('artist of the current track')
  album  = tell('album of the current track')
  track  = tell('name of the current track')
  alert.show(track .."\n".. album .."\n".. artist, 1.75)
end

return spotify
