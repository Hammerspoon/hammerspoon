--- === hs.itunes ===
---
--- Controls for iTunes music player

local itunes = {}

local alert = require "hs.alert"
local as = require "hs.applescript"
local app = require "hs.application"

local applicationName = 'iTunes'
local osVersion = hs.host.operatingSystemVersion()
if osVersion.major >= 11 or osVersion.minor >= 15 then
  applicationName = 'Music'
end

--- hs.itunes.state_paused
--- Constant
--- Returned by `hs.itunes.getPlaybackState()` to indicates iTunes is paused
itunes.state_paused = "kPSp"

--- hs.itunes.state_playing
--- Constant
--- Returned by `hs.itunes.getPlaybackState()` to indicates iTunes is playing
itunes.state_playing = "kPSP"

--- hs.itunes.state_stopped
--- Constant
--- Returned by `hs.itunes.getPlaybackState()` to indicates iTunes is stopped
itunes.state_stopped = "kPSS"

-- Internal function to pass a command to Applescript.
local function tell(cmd)
  local _cmd = 'tell application "' .. applicationName .. '" to ' .. cmd
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
  tell('back track')
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
   return app.get(applicationName) ~= nil
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
   local state = hs.itunes.getPlaybackState()
   if state == hs.itunes.state_playing then
      return true
   elseif state == hs.itunes.state_paused or state == hs.itunes.state_stopped then
      return false
   else  -- unknown state
      return nil
   end
end

--- hs.itunes.getVolume()
--- Function
--- Gets the current iTunes volume setting
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number, between 1 and 100, containing the current iTunes playback volume
function itunes.getVolume() return tell'sound volume' end

--- hs.itunes.setVolume(vol)
--- Function
--- Sets the iTunes playback volume
---
--- Parameters:
---  * vol - A number, between 1 and 100
---
--- Returns:
---  * None
function itunes.setVolume(v)
  v=tonumber(v)
  if not v then error('volume must be a number 1..100',2) end
  return tell('set sound volume to '..math.min(100,math.max(0,v)))
end

--- hs.itunes.volumeUp()
--- Function
--- Increases the iTunes playback volume by 5
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.volumeUp() return itunes.setVolume(itunes.getVolume()+5) end

--- hs.itunes.volumeDown()
--- Function
--- Decreases the iTunes playback volume by 5
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.volumeDown() return itunes.setVolume(itunes.getVolume()-5) end

--- hs.itunes.getPosition()
--- Function
--- Gets the playback position (in seconds) of the current song
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number indicating the current position in the song
function itunes.getPosition() return tell('player position') end

--- hs.itunes.setPosition(pos)
--- Function
--- Sets the playback position of the current song
---
--- Parameters:
---  * pos - A number indicating the playback position (in seconds) to skip to
---
--- Returns:
---  * None
function itunes.setPosition(p)
  p=tonumber(p)
  if not p then error('position must be a number in seconds',2) end
  return tell('set player position to '..p)
end

--- hs.itunes.getDuration()
--- Function
--- Gets the duration (in seconds) of the current song
---
--- Parameters:
---  * None
---
--- Returns:
---  * The number of seconds long the current song is, 0 if no song is playing
function itunes.getDuration()
  local duration = tonumber(tell('duration of current track'))
  return duration ~= nil and duration or 0
end

--- hs.itunes.ff()
--- Function
--- Skips the current playback forwards by 5 seconds
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.ff() return itunes.setPosition(itunes.getPosition()+5) end

--- hs.itunes.rw()
--- Function
--- Skips the current playback backwards by 5 seconds
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function itunes.rw() return itunes.setPosition(itunes.getPosition()-5) end

return itunes
