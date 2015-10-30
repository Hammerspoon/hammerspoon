--- === hs.itunes ===
---
--- Controls for iTunes music player

local itunes = {}

local alert = require "hs.alert"
local as = require "hs.applescript"
local app = require "hs.application"

--- hs.itunes.state_paused
--- Constant
--- Returned by `hs.itunes.getPlaybackState()` to indicates iTunes is paused
itunes.state_paused = "'kPSp'"

--- hs.itunes.state_playing
--- Constant
--- Returned by `hs.itunes.getPlaybackState()` to indicates iTunes is playing
itunes.state_playing = "'kPSP'"

--- hs.itunes.state_stopped
--- Constant
--- Returned by `hs.itunes.getPlaybackState()` to indicates iTunes is stopped
itunes.state_stopped = "'kPSS'"

-- Internal function to pass a command to Applescript.
local function tell(cmd)
  local _cmd = 'tell application "iTunes" to ' .. cmd
  local ok, result = as.applescript(_cmd)
  if ok then
    return result
  else
    return nil
  end
end

--- hs.itunes.playpause()
--- Function
--- Toggles play/pause of current iTunes track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.playpause()
  tell('playpause')
end

--- hs.itunes.play()
--- Function
--- Plays the current iTunes track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.play()
  tell('play')
end

--- hs.itunes.pause()
--- Function
--- Pauses the current iTunes track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.pause()
  tell('pause')
end

--- hs.itunes.next()
--- Function
--- Skips to the next itunes track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.next()
  tell('next track')
end

--- hs.itunes.previous()
--- Function
--- Skips to previous itunes track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.previous()
  tell('previous track')
end

--- hs.itunes.displayCurrentTrack()
--- Function
--- Displays information for current track on screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.displayCurrentTrack()
  local artist = tell('artist of the current track as string') or "Unknown artist"
  local album  = tell('album of the current track as string') or "Unknown album"
  local track  = tell('name of the current track as string') or "Unknown track"
  alert.show(track .."\n".. album .."\n".. artist, 1.75)
end

--- hs.itunes.getCurrentArtist() -> string or nil
--- Function
--- Gets the name of the current Artist
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Artist of the current track, or nil if an error occurred
function itunes.getCurrentArtist()
    return tell('artist of the current track as string')
end

--- hs.itunes.getCurrentAlbum() -> string or nil
--- Function
--- Gets the name of the current Album
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Album of the current track, or nil if an error occurred
function itunes.getCurrentAlbum()
    return tell('album of the current track as string')
end

--- hs.itunes.getCurrentTrack() -> string or nil
--- Function
--- Gets the name of the current track
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the name of the current track, or nil if an error occurred
function itunes.getCurrentTrack()
    return tell('name of the current track as string')
end

--- hs.itunes.getPlaybackState()
--- Function
--- Gets the current playback state of iTunes
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing one of the following constants:
---    - `hs.itunes.state_stopped`
---    - `hs.itunes.state_paused`
---    - `hs.itunes.state_playing`
function itunes.getPlaybackState()
   return tell('get player state')
end

--- hs.itunes.isRunning()
--- Function
--- Returns whether iTunes is currently open. Most other functions in hs.itunes will automatically start the application, so this function can be used to guard against that.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean value indicating whether the iTunes application is running.
function itunes.isRunning()
   return app.get("iTunes") ~= nil
end

--- hs.itunes.isPlaying()
--- Function
--- Returns whether iTunes is currently playing
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean value indicating whether iTunes is currently playing a track, or nil if an error occurred (unknown player state). Also returns false if the application is not running
function itunes.isPlaying()
   -- We check separately to avoid starting the application if it's not running
   if not hs.itunes.isRunning() then
      return false
   end
   state = hs.itunes.getPlaybackState()
   if state == hs.itunes.state_playing then
      return true
   elseif state == hs.itunes.state_paused or state == hs.itunes.state_stopped then
      return false
   else  -- unknown state
      return nil
   end
end

return itunes
