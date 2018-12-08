--- === hs.deezer ===
---
--- Controls for Deezer music player.
---
--- Heavily inspired by 'hs.spotify', credits to the original author.

local deezer = {}

local alert = require "hs.alert"
local as = require "hs.applescript"
local app = require "hs.application"

--- hs.deezer.state_paused
--- Constant
--- Returned by `hs.deezer.getPlaybackState()` to indicates deezer is paused
deezer.state_paused = "kPSp"

--- hs.deezer.state_playing
--- Constant
--- Returned by `hs.deezer.getPlaybackState()` to indicates deezer is playing
deezer.state_playing = "kPSP"

--- hs.deezer.state_stopped
--- Constant
--- Returned by `hs.deezer.getPlaybackState()` to indicates deezer is stopped
deezer.state_stopped = "kPSS"

-- Internal function to pass a command to Applescript.
local function tell(cmd)
    local _cmd = 'tell application "deezer" to ' .. cmd
    local ok, result = as.applescript(_cmd)
    if ok then return result else return nil end
end

--- hs.deezer.playpause()
--- Function
--- Toggles play/pause of current deezer track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function deezer.playpause()
    tell('playpause')
end

--- hs.deezer.play()
--- Function
--- Plays the current deezer track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function deezer.play()
    tell('play')
end

--- hs.deezer.pause()
--- Function
--- Pauses the current deezer track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function deezer.pause()
    tell('pause')
end

--- hs.deezer.next()
--- Function
--- Skips to the next deezer track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function deezer.next()
    tell('next track')
end

--- hs.deezer.previous()
--- Function
--- Skips to previous deezer track
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function deezer.previous()
    tell('previous track')
end

--- hs.deezer.displayCurrentTrack()
--- Function
--- Displays information for current track on screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function deezer.displayCurrentTrack()
    local artist = deezer.getCurrentArtist() or "Unknown artist"
    local album  = deezer.getCurrentAlbum() or "Unknown album"
    local track  = deezer.getCurrentTrack() or "Unknown track"
    alert.show(track .. "\n" .. album .. "\n" .. artist, 1.75)
end

--- hs.deezer.getCurrentArtist()
--- Function
--- Gets the name of the artist of the current track
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Artist of the current track, or nil if an error occurred
function deezer.getCurrentArtist()
    return tell('artist of the loaded track')
end

--- hs.deezer.getCurrentAlbum()
--- Function
--- Gets the name of the album of the current track
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the Album of the current track, or nil if an error occurred
function deezer.getCurrentAlbum()
    return tell('album of the loaded track')
end

--- hs.deezer.getCurrentTrack()
--- Function
--- Gets the name of the current track
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the name of the current track, or nil if an error occurred
function deezer.getCurrentTrack()
    return tell('title of the loaded track')
end

--- hs.deezer.getPlaybackState()
--- Function
--- Gets the current playback state of deezer
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing one of the following constants:
---    - `hs.deezer.state_stopped`
---    - `hs.deezer.state_paused`
---    - `hs.deezer.state_playing`
function deezer.getPlaybackState()
    return tell('get player state')
end

--- hs.deezer.isRunning()
--- Function
--- Returns whether deezer is currently open. Most other functions in hs.deezer will automatically start the application, so this function can be used to guard against that.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean value indicating whether the deezer application is running.
function deezer.isRunning()
    return app.get("Deezer") ~= nil
end

--- hs.deezer.isPlaying()
--- Function
--- Returns whether deezer is currently playing
---
--- Parameters:
---  * None
---
--- Returns:
---  * A boolean value indicating whether deezer is currently playing a track, or nil if an error occurred (unknown player state). Also returns false if the application is not running
function deezer.isPlaying()
    -- We check separately to avoid starting the application if it's not running
    if not hs.deezer.isRunning() then return false end

    local state = hs.deezer.getPlaybackState()
    if state == hs.deezer.state_playing then
        return true
    elseif state == hs.deezer.state_paused or state == hs.deezer.state_stopped then
        return false
    else  -- unknown state
        return nil
    end
end

--- hs.deezer.getVolume()
--- Function
--- Gets the deezer volume setting
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number containing the volume deezer is set to between 1 and 100
function deezer.getVolume() return tell('output volume') end

--- hs.deezer.setVolume(vol)
--- Function
--- Sets the deezer volume setting
---
--- Parameters:
---  * vol - A number between 1 and 100
---
--- Returns:
---  * None
function deezer.setVolume(v)
    v = tonumber(v)
    if not v then error('volume must be a number 1..100', 2) end
    return tell('set output volume to ' .. math.min(100, math.max(0, v)))
end

--- hs.deezer.volumeUp()
--- Function
--- Increases the volume by 5
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function deezer.volumeUp() return deezer.setVolume(deezer.getVolume() + 5) end

--- hs.deezer.volumeDown()
--- Function
--- Reduces the volume by 5
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function deezer.volumeDown() return deezer.setVolume(deezer.getVolume() - 5) end

--- hs.deezer.getPosition()
--- Function
--- Gets the playback position (in seconds) in the current song
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number indicating the current position in the song
function deezer.getPosition() return tell('player position') end

--- hs.deezer.setPosition(pos)
--- Function
--- Sets the playback position in the current song
---
--- Parameters:
---  * pos - A number containing the position (in seconds) to jump to in the current song
---
--- Returns:
---  * None
function deezer.setPosition(p)
    p = tonumber(p)
    if not p then error('position must be a number in seconds', 2) end
    return tell('set player position to ' .. p)
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
function deezer.getDuration()
  local duration = tonumber(tell('duration of loaded track'))
  return duration ~= nil and duration or 0
end

--- hs.deezer.ff()
--- Function
--- Skips the playback position forwards by 5 seconds
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function deezer.ff() return deezer.setPosition(deezer.getPosition() + 5) end

--- hs.deezer.rw()
--- Function
--- Skips the playback position backwards by 5 seconds
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function deezer.rw() return deezer.setPosition(deezer.getPosition() - 5) end

return deezer
