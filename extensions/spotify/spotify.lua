--- === hs.spotify ===
---
--- Controls for Spotify music player

local spotify = {}

local alert = require "hs.alert"
local as = require "hs.applescript"
local app = require "hs.application"

--- hs.spotify.state_paused
--- Constant
--- Returned by `hs.spotify.getPlaybackState()` to indicates Spotify is paused
spotify.state_paused = "kPSp"

--- hs.spotify.state_playing
--- Constant
--- Returned by `hs.spotify.getPlaybackState()` to indicates Spotify is playing
spotify.state_playing = "kPSP"

--- hs.spotify.state_stopped
--- Constant
--- Returned by `hs.spotify.getPlaybackState()` to indicates Spotify is stopped
spotify.state_stopped = "kPSS"

-- Internal function to pass a command to Applescript.
local function tell(cmd)
  local _cmd = 'tell application "Spotify" to ' .. cmd
  local ok, result = as.applescript(_cmd)
  if ok then
    return result
  else
    return nil
  end
end

--- hs.spotify.playpause()
--- Function
--- Toggles play/pause of current Spotify track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function spotify.playpause()
  tell('playpause')
end

--- hs.spotify.play()
--- Function
--- Plays the current Spotify track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function spotify.play()
  tell('play')
end

--- hs.spotify.pause()
--- Function
--- Pauses the current Spotify track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function spotify.pause()
  tell('pause')
end

--- hs.spotify.next()
--- Function
--- Skips to the next Spotify track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function spotify.next()
  tell('next track')
end

--- hs.spotify.previous()
--- Function
--- Skips to previous Spotify track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function spotify.previous()
  tell('previous track')
end

--- hs.spotify.playTrack(id)
--- Function
--- Plays the Spotify track with the given id
---
--- Parameters:
---  * id - The Spotify id of the track to be played
---
--- Returns:
---  * None
function spotify.playTrack(i)
  tell('play track "'..i..'"')
end

--- hs.spotify.displayCurrentTrack()
--- Function
--- Displays information for current track on screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function spotify.displayCurrentTrack()
  local artist = tell('artist of the current track') or "Unknown artist"
  local album  = tell('album of the current track') or "Unknown album"
  local track  = tell('name of the current track') or "Unknown track"
  alert.show(track .."\n".. album .."\n".. artist, 1.75)
end

--- hs.spotify.getCurrentArtist()
--- Function
--- Gets the name of the artist of the current track
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Artist of the current track, or nil if an error occurred
function spotify.getCurrentArtist()
  return tell('artist of the current track')
end

--- hs.spotify.getCurrentAlbum()
--- Function
--- Gets the name of the album of the current track
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Album of the current track, or nil if an error occurred
function spotify.getCurrentAlbum()
  return tell('album of the current track')
end

--- hs.spotify.getCurrentTrack()
--- Function
--- Gets the name of the current track
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the name of the current track, or nil if an error occurred
function spotify.getCurrentTrack()
  return tell('name of the current track')
end
--- hs.spotify.getCurrentTrackId()
--- Function
--- Gets the id of the current track
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the id of the current track, or nil if an error occurred
function spotify.getCurrentTrackId()
  return tell('id of current track')
end

--- hs.spotify.getPlaybackState()
--- Function
--- Gets the current playback state of Spotify
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing one of the following constants:
---    - `hs.spotify.state_stopped`
---    - `hs.spotify.state_paused`
---    - `hs.spotify.state_playing`
function spotify.getPlaybackState()
  return tell('get player state')
end

--- hs.spotify.isRunning()
--- Function
--- Returns whether Spotify is currently open. Most other functions in hs.spotify will automatically start the application, so this function can be used to guard against that.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean value indicating whether the Spotify application is running.
function spotify.isRunning()
  return app.get("Spotify") ~= nil
end

--- hs.spotify.isPlaying()
--- Function
--- Returns whether Spotify is currently playing
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean value indicating whether Spotify is currently playing a track, or nil if an error occurred (unknown player state). Also returns false if the application is not running
function spotify.isPlaying()
  -- We check separately to avoid starting the application if it's not running
  if not spotify.isRunning() then
    return false
  end
  local state = spotify.getPlaybackState()
  if state == spotify.state_playing then
    return true
  elseif state == spotify.state_paused or state == spotify.state_stopped then
    return false
  else  -- unknown state
    return nil
  end
end

--- hs.spotify.getVolume()
--- Function
--- Gets the Spotify volume setting
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number containing the volume Spotify is set to between 1 and 100
function spotify.getVolume() return tell'sound volume' end

--- hs.spotify.setVolume(vol)
--- Function
--- Sets the Spotify volume setting
---
--- Parameters:
---  * vol - A number between 1 and 100
---
--- Returns:
---  * None
function spotify.setVolume(v)
  v=tonumber(v)
  if not v then error('volume must be a number 1..100',2) end
  return tell('set sound volume to '..math.min(100,math.max(0,v)))
end

--- hs.spotify.volumeUp()
--- Function
--- Increases the volume by 5
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function spotify.volumeUp() return spotify.setVolume(spotify.getVolume()+5) end

--- hs.spotify.volumeDown()
--- Function
--- Reduces the volume by 5
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function spotify.volumeDown() return spotify.setVolume(spotify.getVolume()-5) end

--- hs.spotify.getPosition()
--- Function
--- Gets the playback position (in seconds) in the current song
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number indicating the current position in the song
function spotify.getPosition() return tell('player position') end

--- hs.spotify.setPosition(pos)
--- Function
--- Sets the playback position in the current song
---
--- Parameters:
---  * pos - A number containing the position (in seconds) to jump to in the current song
---
--- Returns:
---  * None
function spotify.setPosition(p)
  p=tonumber(p)
  if not p then error('position must be a number in seconds',2) end
  return tell('set player position to '..p)
end

--- hs.spotify.getDuration()
--- Function
--- Gets the duration (in seconds) of the current song
---
--- Parameters:
---  * None
---
--- Returns:
---  * The number of seconds long the current song is, 0 if no song is playing
function spotify.getDuration()
  local duration = tonumber(tell('duration of current track'))
  return duration ~= nil and duration / 1000 or 0
end

--- hs.spotify.ff()
--- Function
--- Skips the playback position forwards by 5 seconds
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function spotify.ff() return spotify.setPosition(spotify.getPosition()+5) end

--- hs.spotify.rw()
--- Function
--- Skips the playback position backwards by 5 seconds
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function spotify.rw() return spotify.setPosition(spotify.getPosition()-5) end

return spotify
