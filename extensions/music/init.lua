--- === hs.music ===
---
--- Controls for Catalina Music player

local music = {}

local alert = require "hs.alert"
local as = require "hs.applescript"
local app = require "hs.application"

--- hs.music.state_paused
--- Constant
--- Returned by `hs.music.getPlaybackState()` to indicates Music is paused
music.state_paused = "kPSp"

--- hs.music.state_playing
--- Constant
--- Returned by `hs.music.getPlaybackState()` to indicates Music is playing
music.state_playing = "kPSP"

--- hs.music.state_stopped
--- Constant
--- Returned by `hs.music.getPlaybackState()` to indicates Music is stopped
music.state_stopped = "kPSS"

-- Internal function to pass a command to Applescript.
local function tell(cmd)
  local _cmd = 'tell application "Music" to ' .. cmd
  local ok, result = as.applescript(_cmd)
  if ok then
    return result
  else
    return nil
  end
end

--- hs.music.playpause()
--- Function
--- Toggles play/pause of current Music track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function music.playpause()
  tell('playpause')
end

--- hs.music.play()
--- Function
--- Plays the current Music track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function music.play()
  tell('play')
end

--- hs.music.pause()
--- Function
--- Pauses the current Music track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function music.pause()
  tell('pause')
end

--- hs.music.next()
--- Function
--- Skips to the next Music track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function music.next()
  tell('next track')
end

--- hs.music.previous()
--- Function
--- Skips to previous Music track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function music.previous()
  tell('back track')
end

--- hs.music.displayCurrentTrack()
--- Function
--- Displays information for current track on screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function music.displayCurrentTrack()
  local artist = tell('artist of the current track as string') or "Unknown artist"
  local album  = tell('album of the current track as string') or "Unknown album"
  local track  = tell('name of the current track as string') or "Unknown track"
  alert.show(track .."\n".. album .."\n".. artist, 1.75)
end

--- hs.music.getCurrentArtist() -> string or nil
--- Function
--- Gets the name of the current Artist
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Artist of the current track, or nil if an error occurred
function music.getCurrentArtist()
    return tell('artist of the current track as string')
end

--- hs.music.getCurrentAlbum() -> string or nil
--- Function
--- Gets the name of the current Album
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Album of the current track, or nil if an error occurred
function music.getCurrentAlbum()
    return tell('album of the current track as string')
end

--- hs.music.getCurrentTrack() -> string or nil
--- Function
--- Gets the name of the current track
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the name of the current track, or nil if an error occurred
function music.getCurrentTrack()
    return tell('name of the current track as string')
end

--- hs.music.getPlaybackState()
--- Function
--- Gets the current playback state of Music
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing one of the following constants:
---    - `hs.music.state_stopped`
---    - `hs.music.state_paused`
---    - `hs.music.state_playing`
function music.getPlaybackState()
   return tell('get player state')
end

--- hs.music.isRunning()
--- Function
--- Returns whether Music is currently open. Most other functions in hs.music will automatically start the application, so this function can be used to guard against that.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean value indicating whether the Music application is running.
function music.isRunning()
   return app.get("Music") ~= nil
end

--- hs.music.isPlaying()
--- Function
--- Returns whether Music is currently playing
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean value indicating whether Music is currently playing a track, or nil if an error occurred (unknown player state). Also returns false if the application is not running
function music.isPlaying()
   -- We check separately to avoid starting the application if it's not running
   if not hs.music.isRunning() then
      return false
   end
   local state = hs.music.getPlaybackState()
   if state == hs.music.state_playing then
      return true
   elseif state == hs.music.state_paused or state == hs.music.state_stopped then
      return false
   else  -- unknown state
      return nil
   end
end

--- hs.music.getVolume()
--- Function
--- Gets the current Music volume setting
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number, between 1 and 100, containing the current Music playback volume
function music.getVolume() return tell'sound volume' end

--- hs.music.setVolume(vol)
--- Function
--- Sets the Music playback volume
---
--- Parameters:
---  * vol - A number, between 1 and 100
---
--- Returns:
---  * None
function music.setVolume(v)
  v=tonumber(v)
  if not v then error('volume must be a number 1..100',2) end
  return tell('set sound volume to '..math.min(100,math.max(0,v)))
end

--- hs.music.volumeUp()
--- Function
--- Increases the Music playback volume by 5
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function music.volumeUp() return music.setVolume(music.getVolume()+5) end

--- hs.music.volumeDown()
--- Function
--- Decreases the Music playback volume by 5
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function music.volumeDown() return music.setVolume(music.getVolume()-5) end

--- hs.music.getPosition()
--- Function
--- Gets the playback position (in seconds) of the current song
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number indicating the current position in the song
function music.getPosition() return tell('player position') end

--- hs.music.setPosition(pos)
--- Function
--- Sets the playback position of the current song
---
--- Parameters:
---  * pos - A number indicating the playback position (in seconds) to skip to
---
--- Returns:
---  * None
function music.setPosition(p)
  p=tonumber(p)
  if not p then error('position must be a number in seconds',2) end
  return tell('set player position to '..p)
end

--- hs.music.getDuration()
--- Function
--- Gets the duration (in seconds) of the current song
---
--- Parameters:
---  * None
---
--- Returns:
---  * The number of seconds long the current song is, 0 if no song is playing
function music.getDuration()
  local duration = tonumber(tell('duration of current track'))
  return duration ~= nil and duration or 0
end

--- hs.music.ff()
--- Function
--- Skips the current playback forwards by 5 seconds
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function music.ff() return music.setPosition(music.getPosition()+5) end

--- hs.music.rw()
--- Function
--- Skips the current playback backwards by 5 seconds
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function music.rw() return music.setPosition(music.getPosition()-5) end

return music
